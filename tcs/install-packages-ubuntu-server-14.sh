#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2018, 2019, 2021 Alan M. Watson <alan@astro.unam.mx>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

########################################################################

prefix=${1:-/usr/local}

########################################################################

# DO NOT update. Let's keep everything the same as at install.
#sudo apt-get -y update

# DO NOT upgrade. Something in the upgrade causes the machines to freeze after
# minutes to hours.
#sudo apt-get -y upgrade

# DO NOT dist-upgrade, as it will install 16.04.
#sudo apt-get -y dist-upgrade

sudo apt-get -y install ntp
sudo apt-get -y install autoconf 
sudo apt-get -y install make 
sudo apt-get -y install gcc
sudo apt-get -y install g++
sudo apt-get -y install gfortran
sudo apt-get -y install ccache
sudo apt-get -y install swig
sudo apt-get -y install libcfitsio3-dev
sudo apt-get -y install libfftw3-dev
sudo apt-get -y install curl
sudo apt-get -y install snmp snmpd
sudo apt-get -y install lm-sensors
sudo apt-get -y install owfs ow-shell
sudo apt-get -y install apache2 apache2-utils
sudo apt-get -y install apache2 cifs-utils
sudo apt-get -y install imagemagick

sudo apt-get -y autoremove
sudo apt-get -y autoclean

########################################################################

# Use UTC.

sudo sh -c "echo UTC >/etc/timezone"
sudo dpkg-reconfigure --frontend noninteractive tzdata

########################################################################

# Boot without GUI
# http://ubuntuforums.org/showthread.php?t=1911143

sudo sh -c "echo manual >/etc/init/lightdm.override"

########################################################################

# Disable plymouth
# https://askubuntu.com/questions/98566/how-do-deactivate-plymouth-boot-screen#98570
sudo mv /etc/init/plymouth.conf /etc/init/plymouth.conf.disabled

########################################################################

rm -rf /tmp/install-packages
mkdir -p /tmp/install-packages
cd "$(dirname "$0")"
cp -r install-packages/. /tmp/install-packages/
cd /tmp/install-packages

########################################################################

# Install cfitsio

cd cfitsio
prefix=/usr/local
./configure --prefix=$prefix
make -j2
sudo make install
make -j2 fpack funpack
sudo mkdir -p $prefix/bin
sudo cp fpack funpack $prefix/bin

########################################################################

# # Install qsilib
# 
# sudo apt-get -y install libusb-dev libftdi-dev libtiff4-dev
# wget -c http://qsimaging.com/downloads/qsiapi-7.2.0.tar.gz
# rm -rf qsiapi-*/
# tar -xzf qsiapi-7.2.0.tar.gz
# cd qsiapi-*/
# ./configure --prefix=$prefix
# make
# sudo make install
# cd ..
# rm -rf qsiapi-*/

########################################################################

# Install fliusb and libfli

cd fliusb-1.3.2/
make
sudo cp fliusb.ko /lib/modules/$(uname -r)/kernel
sudo depmod
cd ..

cd libfli/
make
sudo cp libfli.a $prefix/lib/
sudo cp libfli.h $prefix/include/
cd ..

########################################################################

# Install astrometry.net

sudo apt-get -y install astrometry.net

########################################################################

# Install sextractor

sudo apt-get -y install sextractor

########################################################################

# Install tcl and tcllib

sudo apt-get -y install tcl-dev
sudo apt-get -y install tcllib

########################################################################
