#!/bin/bash

# Prompt for domain input
read -p "Enter your domain (e.g., example.com): " domain

# Step 1: Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx php-fpm php-mbstring php-zip php-gd php-json php-curl php-xml php-pear php-bcmath php-intl php-mysql unzip certbot python3-certbot-nginx

# Step 2: Download and Install PHPMyAdmin
echo "Downloading and installing PHPMyAdmin..."
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
unzip phpMyAdmin-latest-all-languages.zip
sudo mv phpMyAdmin-*-all-languages /usr/share/phpmyadmin
sudo mkdir /usr/share/phpmyadmin/tmp
sudo chmod 777 /usr/share/phpmyadmin/tmp

# Step 3: Configure Nginx for PHPMyAdmin
echo "Configuring Nginx for PHPMyAdmin..."
sudo tee /etc/nginx/sites-available/phpmyadmin > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    
    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable the PHPMyAdmin site and test the configuration
sudo ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Step 4: Obtain SSL Certificate for PHPMyAdmin
echo "Setting up SSL with Certbot for $domain..."
sudo certbot --nginx -d $domain

# Reload Nginx to apply SSL settings
sudo systemctl reload nginx

# Step 5: Configure PHPMyAdmin for Pterodactyl Usage
echo "Configuring PHPMyAdmin for Pterodactyl access..."
sudo tee /usr/share/phpmyadmin/config.inc.php > /dev/null <<EOF
<?php
\$cfg['blowfish_secret'] = 'supersecretkey'; // Use a secure random string here.
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = '127.0.0.1';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
?>
EOF

# Step 6: Final Message
echo "PHPMyAdmin has been successfully installed and configured for access at https://$domain."

# Step 7: Optional Integration Notes
echo "If Pterodactyl is installed, access PHPMyAdmin via https://$domain using your MySQL credentials to manage databases."

echo "Installation and setup complete! Securely manage your Pterodactyl databases through PHPMyAdmin."
