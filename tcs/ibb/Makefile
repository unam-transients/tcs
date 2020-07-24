# This file is part of the UNAM telescope control system.

# $Id: Makefile 3373 2019-10-30 15:09:02Z Alan $

########################################################################

# Copyright © 2011, 2012, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
	
all-ratir		:
	PROJECT="ratir" make all

all-coatlioan		:
	PROJECT="coatlioan" make all

all-ddotioan		:
	PROJECT="ddotioan" make all

all			:
	mkdir -p etc/tcs
	cp ../etc/tcs/config-project-$(PROJECT).tcl etc/tcs/config.tcl
	cd $(PROJECT); \
	for ibb in $$(ls *.prolog | sed 's/.prolog$$//'); do \
	  echo "configuring $$ibb."; \
	  etcdirectory=../etc/ ../ibbconfigurenames $$ibb | sed "s/$$PROJECT-//g" >$$ibb.names; \
	  ../ibbexec $$ibb prolog $$ibb.prolog $$ibb.names $$ibb.epilog epilog; \
	  echo "done."; \
	  rm -f $$ibb.names; \
	done
	rm -rf etc
