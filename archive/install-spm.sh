#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-spm.sh 3373 2019-10-30 15:09:02Z Alan $

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

tar -xzf local.tar.gz

sudo service rsync stop

cd "$(dirname "$0")"

sudo mkdir -p /usr/local/etc
sudo cp local/rsync-spm/rsyncd.conf /usr/local/etc/
sudo cp local/rsync-spm/rsyncd.secrets /usr/local/etc/
sudo chmod o= /usr/local/etc/rsyncd.secrets

sudo service rsync start

sudo mkdir -p /usr/local/etc/archive
sudo cp local/cron/prepare-archive /usr/local/etc/archive
sudo cp local/cron/move-raw-images /usr/local/etc/archive
sudo cp local/cron/make-log-csv-file /usr/local/etc/archive
sudo cp local/cron/make-log-txt-file /usr/local/etc/archive

sudo -u archive crontab <<EOF
MAILTO=alan@astro.unam.mx
0 14 * * * /usr/local/etc/archive/prepare-archive >/home/archive/log.txt 2>&1
EOF
