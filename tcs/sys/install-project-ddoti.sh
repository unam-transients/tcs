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

host=$(uname -n | sed 's/\..*//;s/.*-//')

################################################################################

# /etc/hosts

(
  sed '/^# Start of tcs epilog./q' /etc/hosts
  cat <<"EOF"
# Start of tcs epilog.

10.0.1.1        firewall                oan-ddoti-firewall
10.0.1.2        console                 oan-ddoti-console
10.0.1.3        services                oan-ddoti-services
10.0.1.4        ibb-220                 oan-ddoti-ibb-220
10.0.1.5        ibb-127                 oan-ddoti-ibb-127
10.0.1.6        mount                   oan-ddoti-mount
10.0.1.7        serial                  oan-ddoti-serial
10.0.1.8        access                  oan-ddoti-access
10.0.1.9        control                 oan-ddoti-control
10.0.1.10       airport-express         oan-ddoti-airport-express
10.0.1.20       webcam-a                oan-ddoti-webcam-a
10.0.1.21       webcam-b                oan-ddoti-webcam-b
10.0.1.22       platform                oan-ddoti-platform
10.0.1.23       detectors0              oan-ddoti-detectors0
10.0.1.24       detectors1              oan-ddoti-detectors1
10.0.1.99       spare                   oan-ddoti-spare

132.248.4.26    webcam-c                oan-ddoti-webcam-c
EOF
) | 
sudo cp /dev/stdin /etc/hosts.tmp
sudo chmod o=rw,go=r /etc/hosts.tmp
sudo mv /etc/hosts.tmp /etc/hosts

################################################################################

# crontab

(
  echo 'PATH=/usr/local/bin:/usr/bin:/bin'
  echo 'MAILTO=""'

  cat <<"EOF"
00 21 *  *  *  tcs cleanfiles
*  *  *  *  *  tcs updatevarlatestlink
*  *  *  *  *  tcs updatelocalsensorsfiles
*  *  *  *  *  tcs checkreboot
*  *  *  *  *  tcs checkrestart
*  *  *  *  *  tcs checkhalt
00     *  *  *  *  rsync -aH --exclude="*.tmp" --exclude="*.jpg" --exclude="*.fits" --exclude="*.fits.*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
01-59  *  *  *  *  rsync -aH --exclude="*.tmp" --exclude="debug*.txt" --include="*.txt" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
*      *  *  *  *  rsync -aH --remove-source-files --exclude="*.tmp" --include="*.fits.*" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
EOF
  
  case $host in
  control)
    cat <<"EOF"
*  *  *  *  *  sleep 10; tcs updatesensorsfiles control platform detectors0 detectors1
*  *  *  *  *  tcs updateweatherfiles-oan
00 18 *  *  *  tcs updateweatherfiles-oan -a
*  *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/ /usr/local/var/tcs/oldalerts
00 00 *  *  *  tcs fetchblocks
01 00 *  *  *  tcs loadblocks
*/5 *  *  *  *  sh /usr/local/var/www/tcs/plots.sh
*/5 *  *  *  *  tcs logsensors
EOF
    ;;
  esac
) | sudo crontab

################################################################################

# /etc/rc.local

(

  echo "#!/bin/sh"
  echo "PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

  case $host in
  control)
    # Start the log server as soon as possible.
    echo "tcs startserver log &"
  esac

  # Wait up to 200 seconds for the log server to start.
  echo "for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19"
  echo "do"
  echo "  if tcs log boot summary \"booting tcs on $host.\""
  echo "  then"
  echo "    if test \$i = 0"
  echo "    then"
  echo "      tcs log boot info \"waited 0 seconds to start booting tcs on $host.\""
  echo "    else"
  echo "      tcs log boot info \"waited \${i}0 seconds to start booting tcs on $host.\""
  echo "    fi"
  echo "    break"
  echo "  fi"
  echo "  sleep 10"
  echo "done"  

  case $host in
  platform)
    echo "tcs gpio -i"
    echo "tcs gpio enclosure-lights off"
    echo "tcs gpio enclosure-heater off"
    ;;
  esac

  echo "owserver -c /etc/owfs.conf"

  case $host in
  detectors0)
    echo "tcs instrumentdataserver -f -d rsync://transients.astrossp.unam.mx/ddoti-raw/ &"
    echo "tcs instrumentimageserver C2 control &"
    echo "tcs instrumentimageserver C4 control &"
    ;;
  detectors1)
    echo "tcs instrumentdataserver -f -d rsync://transients.astrossp.unam.mx/ddoti-raw/ &"
    echo "tcs instrumentimageserver C1 control &"
    echo "tcs instrumentimageserver C3 control &"
    ;;
  control)
    echo "tcs instrumentimageserver C1 &"
    echo "tcs instrumentimageserver C2 &"
    echo "tcs instrumentimageserver C3 &"
    echo "tcs instrumentimageserver C4 &"
    echo "tcs webcamimageserver a http://ddoti:ddoti@webcam-a/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver b http://ddoti:ddoti@webcam-b/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver c http://ddoti:ddoti@webcam-c/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver -r 1 -c 640x480+480+600 cz http://ddoti:ddoti@webcam-c/cgi-bin/viewer/video.jpg &"
    echo "tcs allskyimageserver http://132.248.4.140/imagenes/ultima_RED.jpg &"
    echo "mkdir -p /usr/local/var/tcs/reboot"
    echo "mkdir -p /usr/local/var/tcs/restart"
    echo "mkdir -p /usr/local/var/tcs/halt"
    ;;
  esac

  echo "service rsync start"

  echo "tcs startserver -a &"
  
  echo "sleep 10"
  echo "tcs log boot summary \"finished booting tcs on $host.\""

  echo "exit 0"

) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

sudo update-rc.d owserver disable

################################################################################

# /etc/owfs.conf

case $host in
control|platform)
  sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: device = /dev/ttyFTDI-ow
server: port = localhost:4304
! server: server = localhost:4304
EOF
  ;;
*)
  sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: link = /dev/ttyFTDI-ow
server: port = localhost:4304
! server: server = localhost:4304
EOF
  ;;
esac
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
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="AJ02WIFQ", SYMLINK+="ttyFTDI-ow"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="A700L5IY", SYMLINK+="ttyFTDI-ow"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="AI03X2BM", SYMLINK+="ttyFTDI-ow"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="AI03X2BD", SYMLINK+="ttyFTDI-ow"
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

server firewall iburst
server 0.ubuntu.pool.ntp.org
server 1.ubuntu.pool.ntp.org
server 3.ubuntu.pool.ntp.org
server 4.ubuntu.pool.ntp.org
EOF
fi

################################################################################

# /etc/sudoers.d/tcs

sudo rm -f /tmp/sudoers-tcs
(
  echo 'ddoti ALL=(ALL) ALL'
  case $host in
  control)
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs reboot'
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs restart'
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs rebootinstrument'
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs rebootplatform'
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

