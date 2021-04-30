########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-project-ratiroan.sh 3562 2020-05-22 20:04:34Z Alan $

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

10.0.1.1        firewall        ratiroan-firewall
10.0.1.2        access          ratiroan-access
10.0.1.3        services        ratiroan-services
10.0.1.4        rack-ibb        ratiroan-rack-ibb
10.0.1.9        control         ratiroan-control
10.0.1.10       detectors       ratiroan-control
10.0.1.11       irpc            ratiroan-irpc

10.0.1.121      tcs-a           ratiroan-tcs-a
10.0.1.122      tcs-b           ratiroan-tcs-b

192.168.0.20    covers
192.168.0.20    inclinometers
192.168.0.27    mount
192.168.0.90    shutters
192.168.0.90    lights
192.168.0.108   temperatures
192.168.0.109   dome
192.168.0.126   telescope-ibb
192.168.0.128   dome-cabinet-ibb
192.168.0.129   instrument-ibb
192.168.0.130   dome-ibb
192.168.0.132   machine-room-owhub
192.168.0.133   dome-owhub
192.168.0.134   telescope-owhub
192.168.0.136   webcam-a
192.168.0.137   webcam-b
192.168.0.138   webcam-c
192.168.0.139   webcam-d
192.168.0.142   cryostat
192.168.0.151   secondary-xy
192.168.0.152   secondary-z

132.248.4.16    webcam-e
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
*  *  *  *  *  /usr/local/bin/updatevarlatestlink
*  *  *  *  *  /usr/local/bin/updatelocalsensorsfiles
*  *  *  *  *  /usr/local/bin/tcs checkreboot
*  *  *  *  *  /usr/local/bin/tcs checkrestart
EOF

  case $host in
  ratiroan-access)
    # Do not run checkhalt on the Macs; they do not automatically start again after a halt if we cycle the power.
    ;;  
  *)
    cat <<"EOF"
*  *  *  *  *  /usr/local/bin/tcs checkhalt
EOF
    ;;
  esac
  
  case $host in
  ratiroan-control)
    cat <<"EOF"
*   *  *  *  *  sleep 10; /usr/local/bin/updatesensorsfiles services control detectors
*  *  *  *  *  /usr/local/bin/updateweatherfiles-oan
00 18 *  *  *  /usr/local/bin/updateweatherfiles-oan -a
*   *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
*   *  *  *  *  rsync -aH --delete /usr/local/var/tcs/selector rsync://transients.astrossp.unam.mx/ratir-raw/
00  *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ratir-raw/ 
00  00 *  *  *  /usr/local/bin/updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/
EOF
    ;;
  ratiroan-services)
    cat <<"EOF"
*/5 *  *  *  *  /usr/local/bin/logsensors
*/5 *  *  *  *  sh /usr/local/var/www/tcs/plots.sh
*   *  *  *  *  rsync -aH --include="error.txt" --include="warning.txt" --include="summary.txt" --include="info.txt" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ratir-raw/
00  *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ratir-raw/
*/5 *  *  *  *  rsync -aH --remove-source-files --include="*/" --include="*.fits.*" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ratir-raw/
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
  ratiroan-access)
    echo "hostname ratiroan-access"
    ;;
  esac

  case $host in
  ratiroan-services)
    echo "tcs instrumentdataserver -j rsync://transients.astrossp.unam.mx/ratir-raw/ &"
    ;;
  ratiroan-detectors|ratiroan-tcs-a)
    echo "tcs instrumentdataserver -j -d rsync://services/tcs/ &"
    ;;
  ratiroan-control)
    echo "tcs finderdataserver rsync://services/tcs/ &"
    ;;
  esac

  case $host in
  ratiroan-services)
    echo "tcs finderimageserver &"
    echo "instrumentimageserver C0 detectors &"
    echo "instrumentimageserver C1 detectors &"
    echo "instrumentimageserver C2 tcs-a &"
    echo "instrumentimageserver C3 tcs-a &"
    echo "webcamimageserver -c 640x464+0+16 a http://observa:00.observa@webcam-a/jpg/image.jpg &"
    echo "webcamimageserver -c 640x464+0+16 b http://observa:00.observa@webcam-b/jpg/image.jpg &"
    echo "webcamimageserver -c 640x464+0+16 c http://observa:00.observa@webcam-c/jpg/image.jpg &"
    echo "webcamimageserver -c 640x464+0+16 d http://observa:00.observa@webcam-d/jpg/image.jpg &"
    echo "webcamimageserver e http://ratir:ratir@webcam-e/cgi-bin/viewer/video.jpg &"
    echo "tcs allskyimageserver  http://132.248.4.140/imagenes/ultima_RED.jpg &"
    echo "mkdir -p /usr/local/var/tcs/reboot"
    echo "mkdir -p /usr/local/var/tcs/restart"
    echo "mkdir -p /usr/local/var/tcs/halt"
    echo "mkdir -p /usr/local/var/tcs/reboot"
    echo "mkdir -p /usr/local/var/tcs/restart"
    echo "mkdir -p /usr/local/var/tcs/halt"
    ;;
  esac
  
  case $host in
  ratiroan-control)
    echo "owserver -c /etc/owfs.conf"
    ;;
  esac

  case $host in
  ratiroan-control|ratiroan-detectors|ratiroan-tcs-a)
    echo "# This sleep gives the services host time to reboot and start the log server."
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

# /etc/owfs

case $host in
ratiroan-control)
  sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
server: link = machine-room-owhub:10001
server: link = dome-owhub:10001
server: link = telescope-owhub:10001
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

#####################################################################################

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

###########################################################################

# Run /etc/rc.local at startup.

# This is a bit more involved than just running /bin/sh /etc/rc.local.
# First, we need to wait to the host name to be correctly set, as
# commands run from /etc/rc.local may depend on this. Second, we need to
# wait for any background tasks to finish.

case $host in
coatlioan-access)
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
