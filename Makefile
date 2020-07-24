archivedir	=	/usr/local/var/archive

install-cu	:
	sudo -u archive mkdir -p /home/archive/bin
	sudo -u archive cp bin-cu/* /home/archive/bin
	sudo -u archive chmod a+x /home/archive/bin/*
	#
	sudo -u archive crontab <crontab-cu
	#
	sudo -u archive mkdir -p $(archivedir)/etc
	sudo -u archive cp /home/alan/archive/rsyncd.conf-cu    $(archivedir)/etc/rsyncd.conf
	sudo -u archive cp /home/alan/archive/rsyncd.secrets-cu $(archivedir)/etc/rsyncd.secrets
	sudo -u archive chmod u=rw,go= $(archivedir)/etc/rsyncd.secrets
	#
	sudo cp $(archivedir)/etc/* /etc
	sudo service rsync restart
