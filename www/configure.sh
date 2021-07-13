########################################################################

# This file is part of the UNAM telescope control system.

# $Id: configure.sh 3442 2020-02-23 05:00:24Z Alan $

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

autoconf

host=$(uname -n | sed 's/\..*//')
case $host in
ratiroan-services)
  ./configure SITE=ratiroan-services
  ;;
coatlioan-services)
  ./configure SITE=coatlioan-services
  ;;
ddotioan-services)
  ./configure SITE=ddotioan-services
  ;;
colibricu-services)
  ./configure SITE=colibricu-services
  ;;
colibricito)
  ./configure SITE=colibricito
  ;;
tcs-a)
  ./configure SITE=ratir-main
  ;;
tcs-b)
  ./configure SITE=ratir-tcs
  ;;
johnsoncu-control)
  ./configure SITE=johnsoncu-control
  ;;
test-*)
  ./configure SITE=test
  ;;
esac
