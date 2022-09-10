#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#tar -xzf local.tar.gz

case $(hostname | sed 's/\..*//') in
transientsoan-nas)
  prefix=/mnt/volume/
  ;;
*)
  prefix=/mnt/storage/
  ;;
esac

sudo mkdir -p $prefix/local/cron
sudo mkdir -p $prefix/local/etc
sudo mkdir -p $prefix/local/sbin

sudo cp local/cron/update-archive     $prefix/local/cron
sudo cp local/cron/make-log-csv-file  $prefix/local/cron
sudo cp local/cron/make-log-txt-file  $prefix/local/cron

sudo cp local/cron/pull-archive       $prefix/local/cron
sudo cp local/cron/clean-archive      $prefix/local/cron
sudo cp local/etc/*                   $prefix/local/etc
sudo cp local/rsync-nas/*             $prefix/local/etc
sudo cp local/sbin/*                  $prefix/local/sbin

sudo $prefix/local/sbin/localize
