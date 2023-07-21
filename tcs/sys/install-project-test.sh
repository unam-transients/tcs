########################################################################

# This file is part of the UNAM telescope control system.

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

host=$(uname -n | sed 's/\..*//')

################################################################################

# /etc/hosts

(
  sed '/^# Start of tcs epilog./q' /etc/hosts
  cat <<"EOF"
# Start of tcs epilog.
192.168.1.201 test-control control
EOF
) | 
sudo cp /dev/stdin /etc/hosts.tmp
sudo chmod o=rw,go=r /etc/hosts.tmp
sudo mv /etc/hosts.tmp /etc/hosts

################################################################################

# crontab

(
  echo 'MAILTO=""'

  cat <<"EOF"
00 21 *  *  *  /usr/local/bin/tcs cleanfiles
*  *  *  *  *  /usr/local/bin/tcs updatevarlatestlink
*  *  *  *  *  /usr/local/bin/tcs updatelocalsensorsfiles
*  *  *  *  *  /usr/local/bin/tcs checkreboot
*  *  *  *  *  /usr/local/bin/tcs checkrestart
*  *  *  *  *  /usr/local/bin/tcs checkhalt
30 *  *  *  *  /usr/local/bin/tcs updateiersfiles
EOF

  case $host in
  test-control)
    cat <<"EOF"
*   *  *  *  *  sleep 10; /usr/local/bin/tcs updatesensorsfiles control
*   *  *  *  *  /usr/local/bin/tcs updateweatherfiles-oan
00  18 *  *  *  /usr/local/bin/tcs updateweatherfiles-oan -a
*   *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
00  00 *  *  *  /usr/local/bin/tcs updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/
*/5 *  *  *  * /usr/local/bin/tcs logsensors
*   *  *  *  * cd /usr/local/var/www/tcs/; sh plots.sh >plots.txt 2>&1
EOF
    ;;
  esac
  
) | sudo crontab

################################################################################

# /etc/rc.local

(

  echo "#!/bin/sh"
  echo "PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

  # The Minnowboard Turbos come up with / read-only after power cycling.
  # Don't know why, but it causes all sorts of problems.
  if dmesg | grep -iq minnowboard
  then
    echo "test -w /etc || mount -o remount,rw /"
  fi

  # Enable gpios on Minnowboards
  if dmesg | grep -iq minnowboard
  then
    echo "gpio -i"
  fi

  echo "owserver -c /etc/owfs.conf"
  
  case $host in
  test-control)
    echo "tcs instrumentdataserver -f -d rsync://test-control/tcs/ &"
    ;;
  esac
  
  echo "mkdir -p /usr/local/var/tcs/reboot"
  echo "mkdir -p /usr/local/var/tcs/restart"
  echo "mkdir -p /usr/local/var/tcs/halt"
  echo "tcs startserver -A &"  
  echo "exit 0"

) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

################################################################################

# /etc/owfs

sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: device = /dev/ttyFTDI
server: port = localhost:4304
! server: server = localhost:4304
EOF
sudo chmod o=rw,go=r /etc/owfs.conf.tmp
sudo mv /etc/owfs.conf.tmp /etc/owfs.conf

################################################################################

# /etc/rsyncd.conf

sudo cp /dev/stdin <<"EOF" /etc/rsyncd.conf.tmp
uid = nobody
gid = nogroup
use chroot = yes
read only = yes
[ow]
        path = /var/ow/
        read only = true
        filter = + 01.* + 26.* + temperature + humidity + VAD + VDD + HIH3600 + HIH4000 - *
        uid = 0
        gid = 0
[tcs]
        path = /usr/local/var/tcs
        exclude = *.tmp
        read only = false
        uid = 0
        gid = 0
EOF
sudo chmod o=rwx,go=rx /etc/rsyncd.conf.tmp
sudo mv /etc/rsyncd.conf.tmp /etc/rsyncd.conf

# /etc/default/rsync

if test -f /etc/default/rsync
then
  sudo cp /dev/stdin <<"EOF" /etc/default/rsync.tmp
RSYNC_ENABLE=true
RSYNC_OPTS=''
RSYNC_NICE=''
EOF
  sudo chmod o=rwx,go=rx  /etc/default/rsync.tmp
  sudo mv /etc/default/rsync.tmp  /etc/default/rsync
fi

################################################################################

if test -d /etc/udev/rules.d
then
  sudo cp /dev/stdin <<"EOF" /etc/udev/rules.d/99-ttyFTDI.rules
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", SYMLINK+="ttyFTDI"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="Optec, Inc.", ATTRS{product}=="Optec USB/Serial Cable", SYMLINK+="ttyFTDI"
EOF
fi

################################################################################

# /etc/default/rcS

if test -f /etc/default/rcS
then
  sudo cp /dev/stdin <<"EOF" /etc/default/rcS
UTC=yes
FSCKFIX=yes
EOF
fi

################################################################################

# /etc//ntp.conf

if test -f /etc/ntp.conf
then
   sudo cp /dev/stdin /etc/ntp.conf <<EOF
driftfile /var/lib/ntp/ntp.drift

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

restrict -4 default kod notrap nomodify nopeer
restrict -6 default kod notrap nomodify nopeer
restrict 127.0.0.1
restrict ::1

server pool.ntp.org iburst
EOF
fi

################################################################################

# /etc/sudoers.d/tcs

sudo rm -f /tmp/sudoers-tcs
(
  echo 'test ALL=(ALL) ALL'
  case $host in
  test-control)
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs reboot'
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs restart'
    ;;
  esac
) >/tmp/sudoers-tcs
chmod 400 /tmp/sudoers-tcs
if visudo -cf /tmp/sudoers-tcs
then
  sudo cp /tmp/sudoers-tcs /etc/sudoers.d/tcs
  sudo chmod 400 /etc/sudoers.d/tcs
else
  echo 1>&2 "ERROR: sudo file is invalid."
  exit 1
fi
rm -f /tmp/sudoers-tcs

################################################################################

