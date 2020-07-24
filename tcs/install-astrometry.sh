#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-astrometry.sh 3373 2019-10-30 15:09:02Z Alan $

########################################################################

# Copyright © 2012, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

rm -rf /tmp/install-packages
mkdir -p /tmp/install-packages
cp -r install-packages/. /tmp/install-packages/
cd /tmp/install-packages

# Install astrometry.net

sudo apt-get -y install \
  libcairo2-dev libnetpbm10-dev netpbm \
  libpng12-dev libjpeg-dev python-numpy \
  python-pyfits python-dev zlib1g-dev \
  libbz2-dev swig cfitsio-dev

wget -c http://www.astrometry.net/downloads/astrometry.net-0.72.tar.gz
rm -rf astrometry.net-*/
tar -xzf astrometry.net-*.tar.gz
cd astrometry.net-*/
make
make extra
sudo INSTALL_DIR=$prefix/opt/astrometry/ make install
cd ..
sudo rm -rf astrometry.net-*/

(
  for file in $(
    cd $prefix/opt/astrometry
    echo bin/*
  )
  do
    sudo mkdir -p $prefix/$(dirname $file)
    sudo ln -sf $prefix/opt/astrometry/$file $prefix/$file
  done
)
