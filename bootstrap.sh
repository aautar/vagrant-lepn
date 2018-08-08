#!/usr/bin/env bash

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:nginx/stable
sudo apt-get -y update

if ! [ -L /var/www ]; then
  rm -rf /var/www
  ln -fs /vagrant/public /var/www
fi

# Install nginx
sudo apt-get install -y nginx=1.14.*

#Install PostgreSQL
sudo apt-get install -y postgresql-10 postgresql-client-10 postgresql-contrib-10

echo "Changing to dummy password"
sudo -u postgres psql postgres -c "ALTER USER postgres WITH ENCRYPTED PASSWORD 'postgres'"
sudo -u postgres psql postgres -c "CREATE EXTENSION adminpack";

echo "Configuring postgresql.conf"
sudo echo "listen_addresses = '*'" >> /etc/postgresql/10/main/postgresql.conf
sudo echo "logging_collector = on" >> /etc/postgresql/10/main/postgresql.conf

# Edit to allow socket access, not just local unix access
echo "Patching pg_hba to change -> socket access"
sudo echo "host all all all md5" >> /etc/postgresql/10/main/pg_hba.conf

echo "Patching complete, restarting postgresql"
sudo service postgresql restart

# Install NodeJS
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs

# Stop servers
sudo service nginx stop

# Nginx
if [ ! -f /etc/nginx/sites-available/vagrant ]; then
    touch /etc/nginx/sites-available/vagrant
fi

if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

if [ ! -f /etc/nginx/sites-enabled/vagrant ]; then
    ln -s /etc/nginx/sites-available/vagrant /etc/nginx/sites-enabled/vagrant
fi

# Configure host
cat << 'EOF' > /etc/nginx/sites-available/vagrant
server
{
    listen  80;
    root /vagrant/public;
    server_name dev.server.com;
    location "/"
    {
        proxy_pass http://localhost:8989;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Restart servers
sudo service nginx restart

