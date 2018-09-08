#!/bin/bash
clear

echo "Setting your locale correctly on Ubuntu Digitalocean"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
echo "This script must be run as root." 1>&2
exit 1
fi

locale-gen en_US en_US.UTF-8
locale-gen en_US
echo 'LANGUAGE="en_US.utf8"' >> /etc/default/locale
echo 'LC_ALL="en_US.UTF-8"' >> /etc/default/locale

echo ""
read -p "Don't forget to logout and login back to have your locale set correctly. " -n1 -s
echo ""

# Next we increase the max number of open files the server can handle
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
