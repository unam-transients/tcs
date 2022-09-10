#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade

sudo apt-get -y install ntp
sudo apt-get -y install autoconf 
sudo apt-get -y install make 
sudo apt-get -y install gcc
sudo apt-get -y install g++
sudo apt-get -y install gfortran
sudo apt-get -y install swig
sudo apt-get -y install libcfitsio3-dev
sudo apt-get -y install libfftw3-dev
sudo apt-get -y install imagemagick
sudo apt-get -y install curl
sudo apt-get -y install snmp snmpd
sudo apt-get -y install lm-sensors

sudo apt-get -y autoremove
sudo apt-get -y autoclean

########################################################################

# Boot without GUI
# http://ubuntuforums.org/showthread.php?t=1911143

sudo sh -c "echo manual >/etc/init/lightdm.override"

########################################################################

mkdir -p /tmp/install-packages
cp -r install-packages/. /tmp/install-packages/
cd /tmp/install-packages

########################################################################

# Install owfs

# sudo apt-get -y install libfuse-dev
# 
# wget -c http://downloads.sourceforge.net/project/owfs/owfs/2.8p13/owfs-2.8p13.tar.gz
# rm -rf owfs-*/
# tar -xzf owfs*.tar.gz
# cd owfs-*/
# ./configure --prefix=$prefix --disable-owperl --disable-owphp --disable-owpython
# make
# sudo make install
# sudo ldconfig
# cd ..
# rm -rf owfs-*/

########################################################################

# Install astrometry.net

# sudo apt-get -y install libcairo2-dev libnetpbm10-dev netpbm libpng12-dev libjpeg-dev python-numpy
# 
# wget -c http://www.astrometry.net/downloads/astrometry.net-0.38.tar.bz2
# rm -rf astrometry.net-*/
# tar -xjf astrometry.net-*.tar.bz2
# cd astrometry.net-*/
# make
# make extra
# sudo INSTALL_DIR=$prefix/opt/astrometry/ make install
# cd ..
# sudo rm -rf astrometry.net-*/
# 
# (
# 	for file in $(
# 		cd $prefix/opt/astrometry
# 		echo bin/*
# 	)
# 	do
# 		sudo mkdir -p $prefix/$(dirname $file)
# 		sudo ln -sf $prefix/opt/astrometry/$file $prefix/$file
# 	done
# )

########################################################################

# Install qsilib

sudo apt-get -y install libusb-dev libftdi-dev libtiff4-dev
wget -c http://qsimaging.com/downloads/qsiapi-7.2.0.tar.gz
rm -rf qsiapi-*/
tar -xzf qsiapi-7.2.0.tar.gz
cd qsiapi-*/
./configure --prefix=$prefix
make
sudo make install
cd ..
rm -rf qsiapi-*/

########################################################################

# Install fliusb and libfli

cd fliusb-1.3/
make
sudo cp fliusb.ko /lib/modules/$(uname -r)/kernel
sudo depmod
cd ..

cd libfli*/
make
sudo cp libfli.a $prefix/lib/
sudo cp libfli.h $prefix/include/
cd ..

########################################################################

# Install sextractor

# We install sextractor 2.5.0 since it is the last version that does not
# require ATLAS/LAPLACK/BLAS; installing later versions of sextractor
# (e.g., 2.8.6) on Ubuntu is a nightmare and a half.

# wget -c http://www.astromatic.net/download/sextractor/sextractor-2.5.0.tar.gz
# rm -rf sextractor-*/
# tar -xzf sextractor-*.tar.gz
# cd sextractor-*/
# ./configure --prefix=$prefix
# make
# sudo make install
# cd ..
# rm -rf sextractor-*/

########################################################################

# Install tcl and tcllib

sudo apt-get -y install tcl-dev
sudo apt-get -y install tcllib

########################################################################

