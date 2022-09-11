########################################################################

########################################################################

# Copyright © 2011, 2012, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

host	:=	$(shell uname -n | sed 's/\.*//')

default			:
	@echo "error: valid targets are install-monitor, install-client, and install-packages."
	@exit 1

install-monitor		:	install-client
	cp nagios.cfg /etc/nagios3/
	cp cgi.cfg /etc/nagios3/
	cp local-$(host).cfg /etc/nagios3/local.cfg
	cp local-common.cfg /etc/nagios3/local-common.cfg
	rm -f /etc/apache2/conf.d/nagios3.conf
	rm -f /etc/nagios3/htpasswd.users
	cp index.html /usr/share/nagios3/htdocs/index.html
	service nagios3 restart
	service apache2 restart

install-client		:
	cp nrpe.cfg /etc/nagios/
	grep $$(uname -n) /etc/hosts | awk '{ print "server_address=" $$1; }' >>/etc/nagios/nrpe.cfg
	cp check_* /usr/lib/nagios/plugins
	service nagios-nrpe-server restart	

install-packages	:
	apt-get install nagios3 nagios3-doc
	apt-get install nagios-nrpe-server nagios-nrpe-plugin
	-service nagios3 stop
	-dpkg-statoverride --update --add nagios www-data 2710 /var/lib/nagios3/rw
	-dpkg-statoverride --update --add nagios nagios 751 /var/lib/nagios3
	service nagios3 start

# See http://linux.dell.com/repo/community/deb/latest/ and
# http://folk.uio.no/trondham/software/check_openmanage.html
install-dell-omsa-packages	:
	echo 'deb http://linux.dell.com/repo/community/deb/latest /' >/etc/apt/sources.list.d/linux.dell.com.sources.list
	gpg --keyserver pgpkeys.mit.edu --recv-key E74433E25E3D7775
	gpg -a --export E74433E25E3D7775 | apt-key add -
	apt-get update
	apt-get install srvadmin-base
	apt-get install libnet-snmp-perl
	apt-get install libconfig-tiny-perl
