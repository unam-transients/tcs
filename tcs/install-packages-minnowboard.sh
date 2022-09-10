#!/bin/sh

########################################################################

# This file is part of the RATTEL telescope control system.

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

# Remove X11
# https://blog.hostonnet.com/uninstall-gui-from-ubuntu-14-04-lts

sudo apt-get purge -y xterm
sudo apt-get purge -y xorg*
sudo apt-get purge -y x11-apps
sudo apt-get purge -y unity*
sudo apt-get purge -y x11-common
sudo apt-get purge -y x11-utils
sudo apt-get purge -y x11-session-utils x11-xfs-utils x11-xkb-utils x11-xserver-utils
sudo apt-get purge -y gnome-*
sudo apt-get purge -y totem-common
sudo apt-get purge -y gir1.2-totem-plparser-1.0 libtotem-plparser18
sudo apt-get purge -y xdg-utils xdiagnose xinput xdg-user-dirs-gtk xdg-user-dirs
sudo apt-get purge -y apport apport-symptoms python3-apport bluez bluez-cups bluez-alsa brasero-common brltty
sudo apt-get purge -y desktop-file-utils gedit gedit-common gir1.2-freedesktop gir1.2-notify-0.7 gsettings-desktop-schemas 
sudo apt-get purge -y libfile-basedir-perl libfile-desktopentry-perl python-xdg python3-xdg remmina* sound-theme-freedesktop ubuntu-settings
sudo apt-get purge -y adium-theme-ubuntu dmz-cursor-theme gtk2-engines-murrine gtk3-engines-unico hicolor-icon-theme 
sudo apt-get purge -y plymouth-theme-ubuntu-logo plymouth-theme-ubuntu-text ubuntu-sounds ubuntu-ui-toolkit-theme xcursor-themes
sudo apt-get purge -y gir1.2-gstreamer-1.0 gstreamer* 
sudo apt-get purge -y espeak*
sudo apt-get purge -y evolution-data-server-common
sudo apt-get purge -y firefox*
sudo apt-get purge -y gconf*
sudo apt-get purge -y file-roller
sudo apt-get purge -y gamin
sudo apt-get purge -y metacity-common
sudo apt-get purge -y fonts-tlwg-mono
sudo apt-get purge -y nautilus*
sudo apt-get purge -y pulseaudio*
sudo apt-get purge -y policykit*
sudo apt-get purge -y rhythmbox*
sudo apt-get purge -y printer*
sudo apt-get purge -y tracker*
sudo apt-get purge -y transmission*
sudo apt-get purge -y ubuntu-wallpapers*
sudo apt-get purge -y update-manager*
sudo apt-get purge -y usb-creator*
sudo apt-get purge -y  update-notifier*
sudo apt-get purge -y  yelp*
sudo apt-get purge -y  zenity*
sudo apt-get purge -y cups-browsed cups-bsd cups-client  cups-common cups-core-drivers  cups-daemon cups-filters cups-filters-core-drivers cups-pk-helper cups-ppdc cups-server-common
sudo apt-get purge -y libcups2 libcupscgi1 libcupsfilters1  libcupsimage2 libcupsmime1 libcupsppdc1 python-cupshelpers python-cups
sudo apt-get purge -y ubuntuone-client-data
sudo apt-get purge -y apparmor
sudo apt-get purge -y libqt4*
sudo apt-get purge -y qtchooser qtcore4-l10n qtdeclarative5-ubuntu-ui-extras-browser-plugin-assets
sudo apt-get purge -y libdbusmenu-qt5 oxideqt-codecs
sudo apt-get purge -y example-content empathy-common
sudo apt-get purge -y indicator*
sudo apt-get purge -y parted
sudo apt-get purge -y nano notify-osd-icons speech-dispatcher-audio-plugins sphinx-voxforge-hmm-en sphinx-voxforge-lm-en
sudo apt-get purge -y whoopsie whoopsie-preferences libwhoopsie-preferences0 libwhoopsie0
sudo apt-get autoremove -y

########################################################################

sudo apt-get -y update
sudo apt-get -y upgrade
# Do not dist-upgrade as we then can't compile the FLI module.
#sudo apt-get -y dist-upgrade

sudo apt-get -y install nano
sudo apt-get -y install ntp
sudo apt-get -y install autoconf 
sudo apt-get -y install make 
sudo apt-get -y install gcc ccache
sudo apt-get -y install g++
sudo apt-get -y install gfortran
sudo apt-get -y install swig
sudo apt-get -y install libcfitsio3-dev
sudo apt-get -y install libfftw3-dev
#sudo apt-get -y install imagemagick
sudo apt-get -y install curl
sudo apt-get -y install snmp snmpd
sudo apt-get -y install lm-sensors
sudo apt-get -y install owfs
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
./configure --prefix=$prefix
make
sudo make install
make fpack funpack
sudo mkdir -p $prefix/bin
sudo cp fpack funpack $prefix/bin
cd ..

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

cd fliusb/
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

# sudo apt-get -y install \
#   libcairo2-dev libnetpbm10-dev netpbm \
#   libpng12-dev libjpeg-dev python-numpy \
#   python-pyfits python-dev zlib1g-dev \
#   libbz2-dev swig cfitsio-dev
# 
# wget -c http://astrometry.net/downloads/astrometry.net-0.70.tar.gz
# rm -rf astrometry.net-*/
# tar -xzf astrometry.net-*.tar.gz
# cd astrometry.net-*/
# make
# make extra
# sudo INSTALL_DIR=$prefix/opt/astrometry/ make install
# cd ..
# sudo rm -rf astrometry.net-*/

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

########################################################################

# Install sextractor

# We install sextractor 2.5.0 since it is the last version that does not
# require ATLAS/LAPLACK/BLAS; installing later versions of sextractor
# (e.g., 2.8.6) on Ubuntu is a nightmare and a half.

wget -c http://www.astromatic.net/download/sextractor/sextractor-2.5.0.tar.gz
rm -rf sextractor-*/
tar -xzf sextractor-*.tar.gz
cd sextractor-*/
./configure --prefix=$prefix
make
sudo make install
( cd /usr/local/bin; sudo ln -s sex sextractor)
cd ..
rm -rf sextractor-*/

########################################################################

# Install tcl and tcllib

sudo apt-get -y install tcl-dev
sudo apt-get -y install tcllib

########################################################################

