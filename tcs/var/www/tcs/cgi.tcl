########################################################################

# This file is part of the UNAM telescope control system.

# $Id: cgi.tcl 3373 2019-10-30 15:09:02Z Alan $

########################################################################

# Copyright © 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

# These are some helper procedures for CGI scripts. I could use the ncgi
# package, but this takes about two seconds to load on a midrange 2010
# server.

proc decodeurl {s} {
  # Only handles ASCII reliably.
  set s [string map {"+" " " "\\" "%5C"} $s]
  set s [regsub -all {%(..)} $s {\\u00\1}]
  set s [subst -nocommands -novariables $s]
  return $s
}

proc decodequerystring {} {
  global env
  set d [dict create]
  foreach s [split $env(QUERY_STRING) "&:"] {
    set i [string first "=" $s]
    if {$i == -1} {
      set k $s
      set v ""
    } else {
      set k [string range $s 0 $i-1]
      set v [string range $s $i+1 end]
    }
    dict append d [decodeurl $k] [decodeurl $v]
  }
  return $d
}
