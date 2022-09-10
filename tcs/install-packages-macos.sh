########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

# Make sure we have agreed to the Xcode licence.

if ! gcc -v >/dev/null 2>&1
then
  sudo xcodebuild -license
fi

# Install Homebrew.

if ! which -s brew
then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install packages.

sudo -H easy_install pip
sudo -H pip install pyfits

brew update

for package in 				\
	autoconf			\
	tcl-tk				\
	gcc				\
	fftw				\
	swig				\
	cfitsio				\
	sextractor			\
	astrometry-net			\
	alpine				\
	coreutils			\
	gnu-getopt			\
	imagemagick			\
	telnet
do
  if ! brew list | grep -qx "$(basename $package)"
  then
    brew install "$package"
  fi
done

brew upgrade
