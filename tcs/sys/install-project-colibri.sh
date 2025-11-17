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

192.168.100.1     gateway                 colibri-gateway
192.168.100.10    astelco-opentsi         colibri- astelco-opentsi
192.168.100.15    qnap-spare              colibri-qnap-spare
192.168.100.17    qnap-prod               colibri-qnap-prod
192.168.100.23    astelco-pc              colibri-astelco-pc opentsi
192.168.100.23    astelco-mini-pc         colibri-astelco-mini-pc
192.168.100.28    plc                     colibri-plc
192.168.100.29    european-ups            colibri-european-ups
192.168.100.30    american-ups            colibri-american-ups
192.168.100.44    redux                   colibri-redux
192.168.100.47    blue                    colibri-blue
192.168.100.48    red                     colibri-red
192.168.100.49    data                    colibri-data
192.168.100.50    pdu0                    colibri-pdu0
192.168.100.51    pdu1                    colibri-pdu1
192.168.100.52    pdu2                    colibri-pdu2
192.168.100.53    sparepdu                colibri-sparepdu
192.168.100.54    control                 colibri-control
192.168.100.55    rsync                   colibri-rsync
192.168.100.56    instrument              colibri-instrument
192.168.100.57    host0                   colibri-host0
192.168.100.58    host1                   colibri-host1
192.168.100.59    host2                   colibri-host2
192.168.100.61    marmex                  colibri-marmex
192.168.100.62    marsvom2                colibri-marsvom2
192.168.100.63    host3                   colibri-host3
192.168.100.70    webcam-a                colibri-webcam-a
192.168.100.71    webcam-b                colibri-webcam-b
192.168.100.72    webcam-spare-a          colibri-webcam-spare-a
192.168.100.73    webcam-d                colibri-webcam-d
192.168.100.74    webcam-c                colibri-webcam-c
192.168.100.75    webcam-e                colibri-webcam-e
192.168.100.76    webcam-spare-b          colibri-webcam-spare-b
192.168.100.77    webcam-f                colibri-webcam-f
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
00     21 *  *  *  tcs cleanfiles
*      *  *  *  *  tcs updatevarlatestlink
*      *  *  *  *  tcs updatelocalsensorsfiles
*      *  *  *  *  tcs checkreboot
*      *  *  *  *  tcs checkrestart
*      *  *  *  *  tcs checkhalt
00     18 *  *  *  tcs updateiersfiles
00     18 *  *  *  tcs updateleapsecondsfile
00     *  *  *  *  rsync -aH --exclude="*.tmp" --exclude="*.jpg" --exclude="*.fits" --exclude="*.fits.*" /usr/local/var/tcs/ rsync://colibri-rsync/colibri-raw/
01-59  *  *  *  *  rsync -aH --exclude="*.tmp" --exclude="debug*.txt" --include="*.txt" --include="*.json" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://colibri-rsync/colibri-raw/
*      *  *  *  *  rsync -aH --remove-source-files --exclude="*.tmp" --include="*.fits.*" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://colibri-rsync/colibri-raw/
EOF
  
  case $host in
  control)
    cat <<"EOF"
*   *  *  *  *  sleep 10; tcs updatesensorsfiles control instrument
*   *  *  *  *  tcs updateseeingfiles-colibri
*   *  *  *  *  tcs request plc special updateweather
*   *  *  *  *  rsync -a rsync://132.248.4.141/weather/Archive/. /usr/local/var/tcs/weather-b/. ; cd /usr/local/var/tcs/weather-b/; tail -1 $(ls *.txt | sort -r | head -1) | awk '{ print $8; }' >/usr/local/var/tcs/sensors/local/oan-wind-average-speed ; tail -1 $(ls *.txt | sort -r | head -1) | awk '{ print $9; }' >/usr/local/var/tcs/sensors/local/oan-wind-gust-speed
*   *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/ /usr/local/var/tcs/oldalerts
00  00 *  *  *  tcs loadblocks -F
01  00 *  *  *  tcs loadblocks -L
*   *  *  *  *  cd /usr/local/var/www/tcs/; sh plots.sh >plots.txt 2>&1
*/5 *  *  *  *  tcs logsensors
*   *  *  *  *  mkdir -p /usr/local/var/www/tcs/alerts/; rsync --delete --dirs /usr/local/var/tcs/alerts/ /usr/local/var/www/tcs/alerts/
*   *  *  *  *  mkdir -p /usr/local/var/www/tcs/blocks/; rsync --delete --dirs /usr/local/var/tcs/blocks/ /usr/local/var/www/tcs/blocks/
*   *  *  *  *  tcs request selector makealertspage
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
  instrument)
    echo "owserver -d /dev/ttyFTDI-ow-ddrago-close-electronics -d /dev/ttyFTDI-ow-ddrago-control-room -d /dev/ttyFTDI-ow-ogse"
    echo "tcs instrumentimageserver C0 control &"
    echo "tcs instrumentimageserver C1 control &"
    echo "tcs instrumentimageserver C2 control &"
    echo "tcs instrumentdataserver -f -d rsync://colibri-rsync/colibri-raw/ &"
    ;;
  control)
    echo "tcs instrumentimageserver C0 &"
    echo "tcs instrumentimageserver C1 &"
    echo "tcs instrumentimageserver C2 &"
    echo "tcs webcamimageserver -d '0 -0.1 0' a http://colibri:matpud-juxHe7-wiksym@webcam-a/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver b http://colibri:matpud-juxHe7-wiksym@webcam-b/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver c http://colibri:matpud-juxHe7-wiksym@webcam-c/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver d http://colibri:matpud-juxHe7-wiksym@webcam-d/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver e http://colibri:matpud-juxHe7-wiksym@webcam-e/cgi-bin/viewer/video.jpg &"
    echo "tcs webcamimageserver f http://colibri:matpud-juxHe7-wiksym@webcam-f/cgi-bin/viewer/video.jpg &"
    echo "tcs allskyimageserver http://132.248.4.140/imagenes/ultima_RED.jpg &"
    echo "mkdir -p /usr/local/var/tcs/reboot"
    echo "mkdir -p /usr/local/var/tcs/restart"
    echo "mkdir -p /usr/local/var/tcs/halt"
    ;;
  esac
  
  echo "service rsync start"

  echo "tcs startserver -A &"
  
  echo "sleep 10"
  echo "tcs log boot summary \"finished booting tcs on $host.\""

  echo "exit 0"

) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

################################################################################

# /etc/owfs

sudo cp /dev/stdin <<"EOF" /etc/owfs.conf.tmp
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
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="A7009GNK", SYMLINK+="ttyFTDI-ow-ddrago-close-electronics"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="A7009KLW", SYMLINK+="ttyFTDI-ow-ddrago-control-room"
SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", ATTRS{serial}=="AJ02WJ50", SYMLINK+="ttyFTDI-ow-ogse"
#SUBSYSTEMS=="usb", ATTRS{manufacturer}=="FTDI", ATTRS{product}=="FT232R USB UART", SYMLINK+="ttyFTDI"
#SUBSYSTEMS=="usb", ATTRS{manufacturer}=="Optec, Inc.", ATTRS{product}=="Optec USB/Serial Cable", SYMLINK+="ttyFTDI"
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
  echo 'colibri ALL=(ALL) ALL'
  case $host in
  control)
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

