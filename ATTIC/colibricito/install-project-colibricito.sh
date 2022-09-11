########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

192.168.200.100 control                 colibricito-control
192.168.200.195 mount                   colibricito-mount
192.168.128.60 plc                      colibricito-plc
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
#00 21 *  *  *  /usr/local/bin/tcs cleanfiles
*  *  *  *  *  /usr/local/bin/tcs updatevarlatestlink
*  *  *  *  *  /usr/local/bin/tcs checkreboot
*  *  *  *  *  /usr/local/bin/tcs checkrestart
*  *  *  *  *  /usr/local/bin/tcs checkhalt
*  *  *  *  *  /usr/local/bin/tcs updateweatherfiles-satino
*  *  *  *  *  mkdir -p /usr/local/var/tcs/alerts /usr/local/var/tcs/oldalerts; rsync -aH /usr/local/var/tcs/alerts/. /usr/local/var/tcs/oldalerts/.
00 12 *  *  *  /usr/local/bin/tcs stopserver mount
00 00 *  *  *  /usr/local/bin/tcs updatevarlatestlink; rsync -aH /usr/local/etc/tcs/blocks /usr/local/var/tcs/latest/
EOF

) | sudo crontab

################################################################################

# /etc/rc.local

(

  echo "#!/bin/sh"
  echo "PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

  # Start ntp here explicitly. If we use the service command we pick up whatever 
  # NTP server is passed by the DHCP server.
  echo "ntpd &"

  echo "tcs instrumentimageserver C0 &"
  echo "tcs webcamimageserver a http://iris.lam.fr/wp-content/uploads/2013/09/cam-iris-1.jpeg &"
  echo "tcs webcamimageserver b http://iris.lam.fr/wp-content/uploads/2013/09/cam-iris-2.jpeg &"
  echo "tcs webcamimageserver c http://iris.lam.fr/wp-content/uploads/2013/09/cam-iris-3.jpeg &"
  echo "tcs allskyimageserver http://iris.lam.fr/wp-includes/images/ftp_iris/allsky1.jpg &"
  echo "mkdir -p /usr/local/var/tcs/reboot"
  echo "mkdir -p /usr/local/var/tcs/restart"
  echo "mkdir -p /usr/local/var/tcs/halt"

  echo "tcs startserver -a &"
  echo "tcs startserver gcntan &"
  
  echo "exit 0"

) |
sudo cp /dev/stdin /etc/rc.local.tmp
sudo chmod o=rwx,go=rx /etc/rc.local.tmp
sudo mv /etc/rc.local.tmp /etc/rc.local

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

server 0.europe.pool.ntp.org iburst
server 1.europe.pool.ntp.org iburst
server 2.europe.pool.ntp.org iburst
server 3.europe.pool.ntp.org iburst
server ntp.ubuntu.com        iburst
server ntp1.univ-amu.fr      iburst
server ntp2.univ-amu.fr      iburst
EOF
fi

################################################################################

# /etc/sudoers.d/tcs

sudo rm -f /tmp/sudoers-tcs
(
  echo 'coatli ALL=(ALL) ALL'
  case $host in
  colibricito-control)
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


