#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

# One of the uses of Ubuntu 16.04 is running Andor's SDK. This has specific
# requirements on the kernel. Do not upgrade the kernel unnecessarily.

#sudo apt-get -y update
#sudo apt-get -y upgrade
#sudo apt-get -y dist-upgrade
 
sudo systemctl stop systemd-timesyncd
sudo systemctl disable systemd-timesyncd

sudo apt-get -y install ntp
sudo apt-get -y install autoconf
sudo apt-get -y install make
sudo apt-get -y install gcc
sudo apt-get -y install g++
sudo apt-get -y install gfortran
sudo apt-get -y install ccache
sudo apt-get -y install swig
sudo apt-get -y install libfftw3-dev
sudo apt-get -y install curl
sudo apt-get -y install snmp snmpd
sudo apt-get -y install lm-sensors
sudo apt-get -y install owserver ow-shell
sudo apt-get -y install apache2 apache2-utils
sudo apt-get -y install cifs-utils
sudo apt-get -y install imagemagick
sudo apt-get -y install gnuplot
sudo apt-get -y install rsync

sudo apt-get -y autoclean
sudo apt-get -y autoremove

########################################################################

# Use UTC.

sudo timedatectl set-timezone UTC

########################################################################

rm -rf /tmp/install-packages
mkdir -p /tmp/install-packages
cd "$(dirname "$0")"
cp -r install-packages/. /tmp/install-packages/
cd /tmp/install-packages

########################################################################

# Install cfitsio

sudo apt-get -y install libcfitsio-dev libcfitsio-bin

########################################################################

# # Install qsilib

# sudo apt-get -y install libftdi1-dev
# wget -c http://qsimaging.com/downloads/qsiapi-7.6.0.tar.gz
# rm -rf qsiapi-*/
# tar -xzf qsiapi-7.6.0.tar.gz
# cd qsiapi-*/
# ./configure --with-ftd=ftdi1 --prefix=$prefix CXXFLAGS="-fpermissive -I/usr/include/libftdi1" LIBS="-lcfitsio -lftdi1"
# make
# sudo make install
# cd ..
# rm -rf qsiapi-*/

########################################################################

# Install fliusb and libfli

sudo apt-get -y install libelf-dev
cd fliusb-1.3.2-mod/
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

exit

########################################################################

