echo "Setting your locale correctly on Ubuntu Digitalocean"

locale-gen en_US en_US.UTF-8
locale-gen en_US
echo 'LANGUAGE="en_US.utf8"' >> /etc/default/locale
echo 'LC_ALL="en_US.UTF-8"' >> /etc/default/locale

echo ""
read -p "Don't forget to logout and login back to have your locale set correctly. " -n1 -s
echo ""
