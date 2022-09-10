########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/opt/gnu-getopt/bin:/bin:/usr/bin:/usr/local/bin

program=$(basename "$0")

usageerror () {
  echo 1>&2 "usage: $program [-p prefix] [--]"
  exit 1
}

optstring=p:
prefix=/usr/local
if ! getopt -qQ -- "$optstring" "$@"
then
  usageerror
fi
eval set -- "$(getopt -q -- "$optstring" "$@")"
while test "$1" != "--"
do
  case "$1" in
  -p)
    prefix="$2"
    shift 2
    ;;
  *)
    usageerror
    ;;
  esac
done
shift
if test $# != 1
then
  usageerror
fi

server="$1"

mkdir -p "$prefix/var/www/tcs/log"

case "$server" in 
"error"|"warning"|"summary"|"info")
  filename="$server.txt"
  ;;
*)
  filename="info-${server}server.txt"
  ;;
esac

files=$(
  ls $prefix/var/tcs/ | 
  grep '^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$' |
  sort -r | 
  while read dir
  do
    if test -f $prefix/var/tcs/$dir/log/$filename
    then
      echo $prefix/var/tcs/$dir/log/$filename
    fi
  done |
  head -2
)

printf "<pre class=\"log\">"

tac $files /dev/null |
head -1000 |
sort -sr -k 1,2 |
awk '
{
  date = $1;
  if (lastdate != "" && date != lastdate)
    print "\n" lastdate "\n";
  lastdate = date;
  print $0;
}
END {
  if (date != "")
    print "\n" date "\n";
}
' |
sed '
  s/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] //
  s/server: summary: /server: /
  s/client: summary: /client: /
  s/\(tcs [^:][^:]*\): summary: /\1: /
  s/\([^ :]*\): summary: /\1: /
  s/\([^ ]*\)server: /\1: /
  s/\([^ ]*\)client: /\1: /
  s/: info: /: /
  /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/!s/^/  /
  s/&/\&amp;/g
  s/</\&lt;/g
  s/>/\&gt;/g
  s/"/\&quot;/g
  s/α/\&alpha;/g
  s/δ/\&delta;/g
  s/°/\&deg;/g
  s/→/\&rarr;/g
  s/±/\&plusmn;/g
  s/ -\([0-9]\)/ \&minus;\1/g
  s/[^ ]*: error: .*/<emph class="error">&<\/emph>/
  s/[^ ]*: warning: .*/<emph class="warning">&<\/emph>/
' 

printf "</pre>"

