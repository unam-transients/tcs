########################################################################

# This file is part of the UNAM telescope control system.

# $Id: install-project-colibriohp.sh 3614 2020-06-22 19:37:17Z Alan $

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

192.168.100.1     firewall                colibriohp-firewall
192.168.100.23    opentsi                 colibriohp-opentsi
192.168.100.50    access                  colibriohp-access
192.168.100.51    pdu1                    colibriohp-pdu1
192.168.100.52    pdu2                    colibriohp-pdu2
192.168.100.53    sparepdu                colibriohp-sparepdu
192.168.100.54    services                colibriohp-services
192.168.100.55    control                 colibriohp-control
192.168.100.56    detectors               colibriohp-detectors
192.168.100.57    blue                    colibriohp-blue
192.168.100.58    sparelinux              colibriohp-sparelinux
192.168.100.59    sparewindows            colibriohp-sparewindows
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
    ;;
  esac
  
  case $host in
  control)
    cat <<"EOF"
*   *  *  *  *  sleep 10; /usr/local/bin/tcs updatesensorsfiles services control detectors
*   *  *  *  *  /usr/local/bin/tcs updateweatherfiles-colibri
*   *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
#*   *  *  *  *  rsync -aH --delete /usr/local/var/tcs/selector rsync://transients.astrossp.unam.mx/ddoti-raw/
#00  *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/ 
00  00 *  *  *  /usr/local/bin/tcs updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/
EOF
    ;;
  services)
    cat <<"EOF"
*   *  *  *  *  sleep 10; /usr/local/bin/tcs updatesensorsfiles services detectors
*   *  *  *  *  /usr/local/bin/tcs updateweatherfiles-colibri
*   *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
00  00 *  *  *  /usr/local/bin/tcs updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/

*/5 *  *  *  * /usr/local/bin/tcs logsensors
*   *  *  *  * cd /usr/local/var/www/tcs/; sh plots.sh >plots.txt 2>&1
#*   *  *  *  *  rsync -aH --include="error.txt" --include="warning.txt" --include="summary.txt" --include="info.txt" --include="*/" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
#00  *  *  *  *  rsync -aH /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
#*/5 *  *  *  *  rsync -aH --remove-source-files --include="*/" --include="*.fits.fz" --exclude="*" /usr/local/var/tcs/ rsync://transients.astrossp.unam.mx/ddoti-raw/
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
  services)
    echo "# Start the log server as soon as possible."
    echo "tcs startserver log &"
    echo "sleep 5"
    ;;
  *)
    echo "# This sleep gives the services host time to reboot and start the log server."
    echo "sleep 30"
    ;;
  esac

  echo "tcs log boot summary \"booting tcs on $host.\""

  case $host in
  control|detectors)
    echo "owserver -c /etc/owfs.conf"
    ;;
  esac
  
  case $host in
  detectors)
    echo "tcs instrumentdataserver -f -d rsync://services/tcs/ &"
    ;;
  esac

  case $host in
  services)
    echo "owserver -c /etc/owfs.conf"
    echo "tcs instrumentimageserver C0 detectors &"
    echo "tcs webcamimageserver a https://www.colibri-obs.org/wp-content/uploads/2021/01/cam-colibri1.jpeg &"
    echo "tcs allskyimageserver http://iris.lam.fr/wp-includes/images/ftp_iris/allsky01.jpg &"
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
  echo 'ddoti ALL=(ALL) ALL'
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

