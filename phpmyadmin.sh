#!/bin/bash

# Prompt for domain input
read -p "Enter your domain (e.g., example.com): " domain

# Step 1: Update system and install required dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx php-fpm php-mbstring php-zip php-gd php-json php-curl php-xml php-pear php-bcmath php-intl php-mysql unzip certbot python3-certbot-nginx

# Step 2: Prepare and Install PHPMyAdmin
echo "Setting up PHPMyAdmin directory and installing PHPMyAdmin..."
mkdir -p /var/www/phpmyadmin && mkdir -p /var/www/phpmyadmin/tmp/
cd /var/www/phpmyadmin
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-english.tar.gz
tar xvzf phpMyAdmin-latest-english.tar.gz
mv /var/www/phpmyadmin/phpMyAdmin-*-english/* /var/www/phpmyadmin
rm -rf phpMyAdmin-latest-english.tar.gz /var/www/phpmyadmin/phpMyAdmin-*-english/

# Additional permissions and configuration setup
echo "Setting permissions and configuring PHPMyAdmin..."
sudo chown -R www-data:www-data *
mkdir config
chmod o+rw config
cp config.sample.inc.php config/config.inc.php
chmod o+w config/config.inc.php
cp /var/www/phpmyadmin/config/config.inc.php /var/www/phpmyadmin

# Clean up unnecessary files and directories
rm -rf /var/www/phpmyadmin/config
rm -rf /var/www/phpmyadmin/setup

# Step 3: Configure Nginx for PHPMyAdmin
echo "Configuring Nginx for PHPMyAdmin with custom settings..."
sudo tee /etc/nginx/sites-available/phpmyadmin.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;

    root /var/www/phpmyadmin;
    index index.php;

    # Allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable the PHPMyAdmin site and test the configuration
sudo ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf
sudo nginx -t && sudo systemctl reload nginx

# Step 4: Obtain SSL Certificate for PHPMyAdmin
echo "Setting up SSL with Certbot for $domain..."
sudo certbot --nginx -d $domain

# Reload Nginx to apply SSL settings
sudo systemctl restart nginx

# Step 5: Configure PHPMyAdmin for Pterodactyl Usage
echo "Configuring PHPMyAdmin for Pterodactyl access..."
sudo tee /var/www/phpmyadmin/config.inc.php > /dev/null <<EOF
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

# Adjust permissions for security
sudo chown -R www-data:www-data /var/www/phpmyadmin

# Step 6: Final Message
echo "PHPMyAdmin has been successfully installed and configured for access at https://$domain."

# Step 7: Optional Integration Notes
echo "If Pterodactyl is installed, access PHPMyAdmin via https://$domain using your MySQL credentials to manage databases."

echo "Installation and setup complete! Securely manage your Pterodactyl databases through PHPMyAdmin."
