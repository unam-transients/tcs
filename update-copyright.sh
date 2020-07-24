#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: update-copyright.sh 3392 2019-11-13 20:56:40Z Alan $

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

if test $# = 0
then
  set -- "."
fi

svn status -qv "$@" | awk '{ print $NF}' |
while read file
do
  if ! test -f $file 
  then
    :
  elif grep -q "Copyright © .* Alan M\. Watson" $file
  then
    :
    years=$(svn log $file | grep -e '^r[0-9][0-9]* |' | sed 's/[^|]*|[^|]*| //;s/-.*//' | sort -u | awk '{ printf(", %s", $1); }' | sed 's/^, //')
    sed "s/Copyright © [0-9 ,]* Alan M\. Watson/Copyright © $years Alan M. Watson/" $file >$file.update-copyright-sed
    if ! cmp -s $file.update-copyright-sed $file
    then
      echo 1>&2 $file: $years
      mv $file.update-copyright-sed $file
    fi
    rm -f $file.update-copyright-sed
  else
    :
  fi
done
