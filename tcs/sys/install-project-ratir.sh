########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-project-ratir.sh 3562 2020-05-22 20:04:34Z Alan $

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

192.168.0.20    covers
192.168.0.20    inclinometers
192.168.0.27    mount
192.168.0.90    shutters
192.168.0.90    lights
192.168.0.108   temperatures
192.168.0.109   dome
192.168.0.110   dhcp-a
192.168.0.111   dhcp-b
192.168.0.112   dhcp-c
192.168.0.113   dhcp-d
192.168.0.114   dhcp-e
192.168.0.115   dhcp-f
192.168.0.116   dhcp-g
192.168.0.117   dhcp-h
192.168.0.118   dhcp-i
192.168.0.119   dhcp-j
192.168.0.121   tcs-a ntp-a gateway
192.168.0.122   tcs-b ntp-b
192.168.0.123   opticalpc
192.168.0.124   old-cryostat ntp-c
192.168.0.125   ics-cabinet-ibb
192.168.0.126   telescope-ibb
192.168.0.127   tcs-cabinet-ibb
192.168.0.128   dome-cabinet-ibb
192.168.0.129   instrument-ibb
192.168.0.130   dome-ibb
192.168.0.131   control-room-ibb
192.168.0.132   machine-room-owhub
192.168.0.133   dome-owhub
192.168.0.134   telescope-owhub
192.168.0.136   webcam-a
192.168.0.137   webcam-b
192.168.0.138   webcam-c
192.168.0.139   webcam-d
192.168.0.140   redux
192.168.0.141   irpc
192.168.0.142   cryostat
192.168.0.143   spare-b-ibb
192.168.0.151   secondary-xy
192.168.0.152   secondary-z
192.168.0.254   router15

192.168.1.74    old-beta
192.168.1.75    beta

132.248.4.13    ratir
132.248.4.250   haro
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
  case $host in
  tcs-a)
    cat <<"EOF"
00 20 * * * /usr/local/bin/dailyrestart
*  *  * * * /usr/bin/rsync -a rsync://tcs-b/summary-logs /usr/local/var/tcs/summary-logs
00 19 * * * /usr/local/bin/cleanfiles
EOF
  ;;
  tcs-b)
    cat <<"EOF"
*  *  * * * /usr/local/bin/updateweatherfiles
*  *  * * * rsync -aH rsync://tcs-a/ratir-logs /usr/local/var/ratir
*  *  * * * /usr/local/bin/makesummarylog
00 19 * * * /usr/local/bin/cleanfiles
00 20 * * * /usr/local/bin/dailyrestart
*  *  * * * cd /usr/local/bin/var/www/tcs; sh plots.sh >>plots.log 2>&1
EOF
    ;;
  esac
) | sudo crontab

################################################################################

# /etc/rc.local

(
  echo "#!/bin/sh"
  case $host in
  tcs-a)
    cat <<"EOF"
# See https://help.ubuntu.com/community/Internet/ConnectionSharing
iptables-restore </etc/iptables.sav

/usr/local/bin/owserver -p 4304 \
  --link=machine-room-owhub \
  --link=dome-owhub \
  --link=telescope-owhub

sleep 10

mkdir -p /var/ow/
/usr/local/bin/owfs -m /var/ow --allow_other --server=tcs-a:4304

/usr/local/bin/instrumentimageserver -p /usr/local &
EOF
    ;;
    tcs-b)
    cat <<"EOF"
mkdir -p /var/ow/
/usr/local/bin/owfs -m /var/ow --allow_other --server=tcs-a:4304

/usr/local/bin/webcamimageserver -c 640x464+0+16 a http://observa:00.observa@webcam-a/jpg/image.jpg &
/usr/local/bin/webcamimageserver -c 640x464+0+16 b http://observa:00.observa@webcam-b/jpg/image.jpg &
/usr/local/bin/webcamimageserver -c 640x464+0+16 c http://observa:00.observa@webcam-c/jpg/image.jpg &
/usr/local/bin/webcamimageserver -c 640x464+0+16 d http://observa:00.observa@webcam-d/jpg/image.jpg &
/usr/local/bin/webcamimageserver e http://ratir:ratir@webcam-e/cgi-bin/viewer/video.jpg &
/usr/local/bin/allskyimageserver -p /usr/local &
/usr/local/bin/finderimageserver -p /usr/local &
EOF
  esac
  echo "/usr/local/bin/tcs startserver -a &"
  echo "exit 0"
) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

################################################################################

# Run /etc/rc.local at startup.

# This is a bit more involved than just running /bin/sh /etc/rc.local.
# First, we need to wait to the host name to be correctly set, as
# commands run from /etc/rc.local may depend on this. Second, we need to
# wait for any background tasks to finish.

case $host in
coatlioan-control|coatlioan-data)
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
