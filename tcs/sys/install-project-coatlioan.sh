########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-project-coatlioan.sh 3562 2020-05-22 20:04:34Z Alan $

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

################################################################################

host=$(uname -n | sed 's/\..*//;s/.*-//')

################################################################################

# /etc/hosts

(
  sed '/^# Start of tcs epilog./q' /etc/hosts
  cat <<"EOF"
# Start of tcs epilog.

10.0.1.1        firewall                coatlioan-firewall
10.0.1.2        access                  coatlioan-access
10.0.1.3        services                coatlioan-services
10.0.1.4        ibb-220                 coatlioan-ibb-220
10.0.1.5        ibb-127                 coatlioan-ibb-127
10.0.1.6        mount                   coatlioan-mount
10.0.1.7        serial                  coatlioan-serial
10.0.1.8        pc                      coatlioan-pc
10.0.1.9        control                 coatlioan-control
10.0.1.10       airport-express         coatlioan-airport-express
10.0.1.11       c0                      coatlioan-c0
10.0.1.12       d0                      coatlioan-d0
10.0.1.13       e0                      coatlioan-e0
10.0.1.14       e1                      coatlioan-e1
10.0.1.15       instrument              coatlioan-instrument C0-host
10.0.1.16       platform                coatlioan-platform
10.0.1.20       webcam-a                coatlioan-webcam-a
10.0.1.21       webcam-b                coatlioan-webcam-b
10.0.1.99       spare                   coatlioan-spare

132.248.4.16    webcam-c                coatlioan-webcam-c
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
EOF

  case $host in
  access)
    # Do not run checkhalt on the Macs; they do not automatically start again after a halt if we cycle the power.
    ;;  
  *)
    cat <<"EOF"
*  *  *  *  *  /usr/local/bin/tcs checkhalt
EOF
  esac

  case $host in
  control)
    cat <<"EOF"
*  *  *  *  *  sleep 10; /usr/local/bin/tcs updatesensorsfiles services control c0 d0 platform instrument
*  *  *  *  *  /usr/local/bin/tcs updateweatherfiles-oan
00 18 *  *  *  /usr/local/bin/tcs updateweatherfiles-oan -a
*  *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
00 *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/coatli-raw/
*  *  *  *  *  rsync -aH --delete /usr/local/var/tcs/selector rsync://transients.astrossp.unam.mx/coatli-raw/
00 00 *  *  *  /usr/local/bin/tcs updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/
EOF
    ;;
  services)
    cat <<"EOF"
*/5 *  *  *  * /usr/local/bin/tcs logsensors
*   *  *  *  *  rsync -aH --include="error.txt" --include="warning.txt" --include="summary.txt" --include="info.txt" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/coatli-raw/
00  *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/coatli-raw/
*/5 *  *  *  *  rsync -aH --remove-source-files --include="*/" --include="*.fits.*" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/coatli-raw/
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
  access)
    echo "hostname coatlioan-access"
    ;;
  esac

  case $host in
  [cdf][01]|platform)
    echo "gpio -i"
    ;;
  esac
  case $host in
  c0|platform)
    echo "gpio enclosure-lights off"
    echo "gpio enclosure-heater off"
    ;;
  esac
  
  case $host in
  [cde]0|control|platform|instrument)
    echo "owserver -c /etc/owfs.conf"
    ;;
  esac

  case $host in
  services)
    echo "tcs instrumentdataserver -f rsync://transients.astrossp.unam.mx/coatli-raw/ &"
    ;;
  instrument)
    echo "tcs instrumentdataserver -f -d rsync://services/tcs/ &"
    ;;
  esac

  case $host in
  services)
    echo "tcs instrumentimageserver C0 instrument &"
    echo "tcs webcamimageserver a http://coatli:coatli@webcam-a/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver b http://coatli:coatli@webcam-b/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver c http://coatli:coatli@webcam-c/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver -r -2 -c 640x480+200+500 cz http://coatli:coatli@webcam-c/cgi-bin/viewer/video.jpg &"
    echo "tcs allskyimageserver http://132.248.4.251:50/~allsky/imagenes/ultima_RED.jpg &"
    echo "mkdir -p /usr/local/var/tcs/reboot"
    echo "mkdir -p /usr/local/var/tcs/restart"
    echo "mkdir -p /usr/local/var/tcs/halt"
    ;;
  esac
  
  echo "service rsync start"

  case $host in
  [cde][01]|control|platform|instrument)
    echo "# This sleep gives the main host time to reboot and start the log server."
    echo "sleep 30"
    ;;
  esac
  echo "tcs startserver -a &"
  
  echo "exit 0"

) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

sudo update-rc.d owserver disable

################################################################################

# /etc/owfs.conf

case $host in
services|control|platform)
  sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: device = /dev/ttyFTDI
server: port = localhost:4304
! server: server = localhost:4304
EOF
  ;;
*)
  sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: link = /dev/ttyFTDI
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
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", SYMLINK+="ttyFTDI"
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
EOF
fi

################################################################################

# Run /etc/rc.local at startup.

# This is a bit more involved than just running /bin/sh /etc/rc.local.
# First, we need to wait to the host name to be correctly set, as
# commands run from /etc/rc.local may depend on this. Second, we need to
# wait for any background tasks to finish.

case $host in
access)
  sudo cp /dev/stdin <<"EOF" /Library/LaunchDaemons/local.localhost.startup.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>local.localhost.rc.local</string>
  <key>Disabled</key>          <false/>
  <key>RunAtLoad</key>         <true/>
  <key>KeepAlive</key>         <false/>
  <key>LaunchOnlyOnce</key>    <true/>
  <key>StandardOutPath</key>   <string>/var/log/rc.local.log</string>
  <key>StandardErrorPath</key> <string>/var/log/rc.local.log</string>
  <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string>
      <string>-xc</string>
      <string>while test $(uname -n) = localhost; do sleep 1; done; . /etc/rc.local; wait</string>
  </array>
</dict>
</plist>
EOF
  sudo chmod u=rw,go=r /Library/LaunchDaemons/local.localhost.startup.plist
  ;;
esac

################################################################################

# /etc/sudoers.d/tcs

sudo rm -f /tmp/sudoers-tcs
(
  echo 'coatli ALL=(ALL) ALL'
  case $host in
  services)
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs rebootsoon'
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/local/bin/tcs restartsoon'
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

