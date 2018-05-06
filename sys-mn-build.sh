#!/bin/bash
clear

# The syscoin repository on GitHub
GitHubSys=https://www.github.com/syscoin/syscoin
GitHubSen=https://github.com/syscoin/sentinel.git

STRING1="Welcome to the Syscoin interactive install method."
STRING2="Updating system and installing required packages."
STRING3="Switching to Aptitude"
STRING4="Some optional installs"
STRING5="Starting your Masternode"
STRING6="Now, you need to finally start your masternode in the following order:"
STRING7="Go to your desktop wallet and go to the Masternodes Tab"
STRING8="Select the masternode to be started (right click to select) and choose start alias"
STRING9=""

# Check if we are root
if [ "$(id -u)" != "0" ]; then
echo "This script must be run as root." 1>&2
exit 1
fi

# First we increase the max number of open files the server can handle
cat >> /etc/sysctl.conf << EOL

fs.file-max = 8192
EOL

sysctl -p

cat >> /etc/security/limits.conf << EOL

* soft     nproc          8192
* hard     nproc          8192
* soft     nofile         8192
* hard     nofile         8192
root soft     nproc          8192
root hard     nproc          8192
root soft     nofile         8192
root hard     nofile         8192
EOL

cat >> /etc/pam.d/common-session << EOL

session required pam_limits.so
EOL

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 18.04 LTS?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"

# Get the external IP of the VPS
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`

clear

echo $STRING1

cat  << EOL

################################# PLEASE READ ################################

You can choose between two installation options: default and advanced.

The advanced installation will install and run the masternode under a non-root
user. If you don't know what that means, use the default installation method.

##############################################################################

EOL

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]
then
USER=syscoin
read -e -p "Password for unprivileged User : " password
adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null
echo $USER:$password | chpasswd > /dev/null
echo "" && echo 'Added user "syscoin"' && echo ""
else
USER=root
fi

USERHOME=`eval echo "~$USER"`

sleep 2

clear

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key ( # THE KEY YOU GENERATED with masternode genkey) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

echo $STRING9
echo $STRING2
sleep 10

# Generating Random Passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# Update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install htop
apt-get -qq install build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev libminiupnpc-dev &&
apt-get -qq install software-properties-common &&
apt-get -qq update &&
apt-get -qq install python virtualenv git unzip pv &&
add-apt-repository -y ppa:bitcoin/bitcoin &&
apt-get -qq install libdb4.8-dev libdb4.8++-dev

sleep 5
clear

echo $STRING3
apt-get -qq install aptitude

echo $STRING4

if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
aptitude -y install fail2ban
service fail2ban restart
fi

if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
apt-get -qq install ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw limit ssh/tcp
ufw allow 8369/tcp
ufw logging on
yes | ufw enable
ufw status
fi

sleep 5

# Make a 4 Gigabyte swapfile
fallocate -l 4G /swapfile &&
chmod 600 /swapfile
mkswap /swapfile &&
swapon /swapfile &&

# Ensure to use the swapfile after a reboot
cat >> /etc/fstab << EOL
/swapfile none swap sw 0 0
EOL

sleep 3

echo $STRING9
echo "Now we are going to compile the syscoin binaries"
echo $STRING9

read -p "Compile duration is approximately 40 minutes. Press any key when you are ready to compile. " -n1 -s

echo $STRING9

# Get Syscoin repository from GitHub
cd $USERHOME
su -c "mkdir $USERHOME/buildsys" $USER
cd buildsys
su -c "git clone $GitHubSys" $USER &&
cd syscoin

# Build Syscoin Core from sources
su -c "$USERHOME/buildsys/syscoin/autogen.sh" $USER &&
su -c "$USERHOME/buildsys/syscoin/configure" $USER &&
su -c "make" $USER &&
make install

echo $STRING9
echo "Syscoin Build completed"
echo $STRING9


read -p "The syscoin binaries have been compiled. Press any key to proceed... " -n1 -s

echo $STRING9

# Setup Syscoin core configuration
su -c "mkdir  $USERHOME/.syscoincore" $USER
su -c "touch $USERHOME/.syscoincore/syscoin.conf" $USER

# Populate syscoin.conf
cat > $USERHOME/.syscoincore/syscoin.conf << EOL
#
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
#
listen=1
server=1
daemon=1
maxconnections=24
#
masternode=1
masternodeprivkey=${KEY}
externalip=${IP}
port=8369
EOL

# Remove write and read access from other nonpriviliged users
chmod 0600 $USERHOME/.syscoincore/syscoin.conf

clear

echo $STRING5

sleep 3

# Create Syscoind Service
cat > /etc/systemd/system/syscoind.service << EOL
[Unit]
Description=syscoind
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/syscoind -conf=${USERHOME}/.syscoincore/syscoin.conf -datadir=${USERHOME}/.syscoincore
ExecStop=/usr/local/bin/syscoind -conf=${USERHOME}/.syscoincore/syscoin.conf -datadir=${USERHOME}/.syscoincore stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL

# Enable and start syscoind via systemctl
systemctl enable syscoind
systemctl start syscoind

# Show the syscoind status
echo $STRING9
echo $STRING9
su -c "/usr/local/bin/syscoin-cli getinfo" $USER

sleep 6

clear

#-----------------------------------------------------------------------------------------------------
#
# Next, set up sentinel for Masternode monitoring
#
#-----------------------------------------------------------------------------------------------------

clear

# Get Sentinel repository from GitHub
cd $USERHOME
su -c "mkdir $USERHOME/monitor" $USER
cd $USERHOME/monitor
su -c "git clone $GitHubSen" $USER &&
cd $USERHOME/monitor/sentinel
su -c "touch sentinel.conf" $USER

# Populate sentinel.conf
cat > $USERHOME/monitor/sentinel/sentinel.conf << EOL
#
# Path to SyscoinCore
syscoin_conf=${USERHOME}/.syscoincore/syscoin.conf

# We are on mainnet
network=mainnet

# Database connection details
db_name=${USERHOME}/monitor/sentinel/database/sentinel.db
db_driver=sqlite
EOL

# Finish Sentinel setup
su -c "virtualenv venv" $USER

# Install Sentinel dependencies
su -c "venv/bin/pip install -r requirements.txt" $USER

echo $STRING9
echo $STRING6
echo $STRING9
echo $STRING7
echo $STRING9
echo $STRING8
echo $STRING9
sleep 5

echo $STRING9

read -p "Press any key to continue but only after you have completed the above steps... " -n1 -s

# Check Masternode Status
su -c "/usr/local/bin/syscoin-cli masternode status" $USER

pause 10

# Set sentinel in crontab
(
su -c "crontab -l 2>/dev/null
echo '*/10 * * * * cd /home/syscoin/monitor/sentinel && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log'" $USER
) | su -c "crontab" $USER

clear

echo "Wait for complete Masternode Sync before proceeding: "

until su -c "/usr/local/bin/syscoin-cli mnsync status 2>/dev/null | grep 'MASTERNODE_SYNC_FINISHED' > /dev/null" $USER
do
for (( i=0; i<${#CHARS}; i++ ))
do
sleep 3
echo -en "${CHARS:$i:1}" "\r"
done
done

# Check sentinel status
echo "Following is the sentinel status (empty output is OK)"
cd $USERHOME/monitor/sentinel
su -c "venv/bin/python bin/sentinel.py" $USER

echo $STRING9
echo "Following is the result of the Masternode Sync Status: "
echo $STRING9
su -c "/usr/local/bin/syscoin-cli mnsync status" $USER
echo $STRING9
echo "Following is the result of the Masternode Status: "
echo $STRING9
su -c "/usr/local/bin/syscoin-cli masternode status" $USER
echo $STRING9
sleep 5
echo "   Masternode setup completed.   "
echo $STRING9
