#!/bin/bash

# Check out the blog post at:
#
#    http://www.philipotoole.com/influxdb-and-grafana-howto
#
# for full details on how to use this script.

AWS_EC2_HOSTNAME_URL=http://ec2-54-177-19-97.us-west-1.compute.amazonaws.com
INFLUXDB_DATABASE=test_db
INFLUXDB_PKG=influxdb_latest_amd64.deb
INFLUXDB_URL=http://s3.amazonaws.com/influxdb/$INFLUXDB_PKG
GRAFANA_VER=grafana-1.8.1
GRAFANA_PKG=$GRAFANA_VER.tar.gz
GRAFANA_URL=http://grafanarel.s3.amazonaws.com/$GRAFANA_PKG
GRAFANA_CONFIG_GIST=https://gist.githubusercontent.com/otoolep/c58991dec54711026b77/raw/c5af837b93032d5b929fef0ea0b262648ddd4b7f/gistfile1.js

echo "Downloading and installing Influxdb."
wget $INFLUXDB_URL
sudo dpkg -i $INFLUXDB_PKG
sudo /etc/init.d/influxdb start

echo "Downloading and installing Grafana."
wget $GRAFANA_URL
tar xvfz $GRAFANA_PKG

echo "Downloading and installing nginx."
sudo apt-get -y install nginx-full
sudo sed -i "s|/usr/share/nginx/html|/home/ubuntu/$GRAFANA_VER|g" /etc/nginx/sites-available/default
sudo service nginx restart

public_hostname=`curl -s $AWS_EC2_HOSTNAME_URL`
if [ $? -eq 0 ]; then
    echo "Public hostname of this EC2 instance is: $public_hostname"
else
    echo "Failed to determine EC2 public hostname."
    echo "Falling back to local hostname."
    public_hostname=`hostname`
fi

echo "Configuring Grafana."
wget https://gist.githubusercontent.com/otoolep/c58991dec54711026b77/raw/606c0f5adccba4153c5daa016711f2e5350f6939/gistfile1.js -O $GRAFANA_VER/config.js
sed -i "s|PUBLIC_HOSTNAME|$public_hostname|g" $GRAFANA_VER/config.js

echo "Creating Influxdb database $INFLUXDB_DATABASE."
curl -s "http://localhost:8086/db?u=root&p=root" -d "{\"name\": \"test_db\"}"

echo "Downloading sine wave generation program."
curl -s https://gist.githubusercontent.com/otoolep/3d5741e680bf76021f77/raw/1d81a1ad4771659b008b9c346b4dd20ef1b72536/sine.py >sine.py

echo -e "Configuration complete. You can find InfluxDB and Grafana at the URLs below.\n"
echo "Influxdb URL:     http://$public_hostname:8083"
echo "Grafana URL:      http://$public_hostname"
