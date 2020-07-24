# http://devopspy.com/python/install-python-3-6-ubuntu-lts/

sudo apt-get update
sudo apt-get install build-essential libpq-dev libssl-dev openssl libffi-dev zlib1g-dev
sudo apt-get install python3-pip python3-dev

sudo apt-get install sqlite3 libsqlite3-dev

sudo rm -rf /tmp/install-python3.6
mkdir /tmp/install-python3.6
cd /tmp/install-python3.6

wget https://www.python.org/ftp/python/3.6.3/Python-3.6.3.tgz
tar -xvf Python-3.6.3.tgz
cd Python-3.6.3
sudo ./configure --enable-optimizations
sudo make -j8
sudo make install
sudo pip3 install --upgrade pip
sudo pip3 install wheel
sudo pip3 install --upgrade setuptools

sudo pip3 install ligo.skymap