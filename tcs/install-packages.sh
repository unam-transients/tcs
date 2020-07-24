#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-packages.sh 3373 2019-10-30 15:09:02Z Alan $

########################################################################

# Copyright © 2011, 2012, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

sudo apt-get -y install autoconf make gcc g++ gfortran swig libcfitsio3-dev libfftw3-dev
sudo apt-get -y install imagemagick
sudo apt-get -y install curl
sudo apt-get -y install snmp snmpd

mkdir -p /tmp/install-packages
cp -r install-packages/. /tmp/install-packages/
cd /tmp/install-packages

# Install owfs

sudo apt-get -y install libfuse-dev

wget -c http://downloads.sourceforge.net/project/owfs/owfs/2.8p13/owfs-2.8p13.tar.gz
rm -rf owfs-*/
tar -xzf owfs*.tar.gz
cd owfs-*/
./configure --prefix=$prefix --disable-owperl --disable-owphp --disable-owpython
make
sudo make install
sudo ldconfig
cd ..
rm -rf owfs-*/

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

# Install qsilib

sudo apt-get -y install libusb-dev libftdi-dev libtiff4-dev

wget -c http://www.qsimaging.com/downloads/qsiapi-4.6.4.tar.gz
rm -rf qsiapi-*/
tar -xzf qsiapi-*.tar.gz
cd qsiapi-*/
./configure --prefix=$prefix
make
sudo make install
cd ..
rm -rf qsiapi-*/

# Install fliusb

cd fliusb/
pwd
make
sudo make install
cd ..

# Install libfli

cd libfli/
pwd
make
sudo cp libfli.a $prefix/lib/
sudo cp libfli.h $prefix/include/
cd ..

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

# Install python 2.7 for Leonid

# wget http://www.python.org/ftp/python/2.7.2/Python-2.7.2.tar.bz2
# rm -rf Python-*/
# tar -xjf Python-*.tar.bz2 
# cd Python-*/
# ./configure 
# make
# sudo make install
# cd ..
# rm -rf Python-*/

# Install Tcl

#wget -c http://downloads.activestate.com/ActiveTcl/releases/8.6.0.0b6/ActiveTcl8.6.0.0b6.295132-linux-x86_64-threaded.tar.gz
wget -c http://downloads.activestate.com/ActiveTcl/releases/8.6.0.0/ActiveTcl8.6.0.0.296563-linux-x86_64-threaded.tar.gz
rm -rf ActiveTcl*/
tar -xzf ActiveTcl*.tar.gz
cd ActiveTcl*/
sudo rm -rf $prefix/opt/tcl
sudo sh install.sh <<EOF

A
$prefix/opt/tcl

EOF
cd ..
rm -rf ActiveTcl*/

tclsh=$prefix/opt/tcl/bin/tclsh8.6

(
	for file in $(
		cd $prefix/opt/tcl
		echo bin/* lib/* include/* man/man*/*
	)
	do
		sudo mkdir -p $prefix/$(dirname $file)
		sudo ln -sf $prefix/opt/tcl/$file $prefix/$file
	done
)

sudo rm -f $prefix/bin/tclsh
sudo cp /dev/stdin $prefix/bin/tclsh <<EOF
#!/bin/sh
exec "$tclsh" "\$@"
EOF
sudo chmod a+rx /usr/local/bin/tclsh

wget -c http://sourceforge.net/projects/tcllib/files/tcllib/1.13/tcllib-1.13.tar.gz
rm -rf tcllib*/
tar -xzf tcllib-*.tar.gz
cd tcllib-*/
sudo $tclsh installer.tcl <<EOF
y
EOF
cd ..
rm -rf tcllib-*/
