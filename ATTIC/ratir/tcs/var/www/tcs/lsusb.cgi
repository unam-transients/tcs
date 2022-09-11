#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

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

#\
exec tclsh8.6 -encoding "utf-8" "$0" ${1+"$@"}

catch {

  set scriptdir [file dirname [info script]]
  source [file join $scriptdir "cgi.tcl"]
  set query [decodequerystring]

  set prefix [file normalize [file join [file dirname [file normalize [info script]]] ".." ".." ".."]]
  source [file join $prefix "lib" "tcs" "packages.tcl"]

  package require utcclock
  
  set timestamp [utcclock::format now 0]
  set host [info host]
  
  set text ""
  
  set text "$text\$ lsusb\n"
  set channel [open "|/usr/sbin/lsusb" "r"]
  chan configure $channel -translation "lf"
  chan configure $channel -encoding "utf-8"
  set text "$text[read $channel]\n"
  close $channel

  set text "$text\$ lsusb -t\n"
  set channel [open "|/usr/sbin/lsusb -t" "r"]
  chan configure $channel -translation "lf"
  chan configure $channel -encoding "utf-8"
  set text "$text[read $channel]\n"
  close $channel

  chan configure stdout -translation "crlf"
  chan configure stdout -encoding "utf-8"
  puts "Content-Type: text/html; charset=UTF-8"
  puts ""
  puts "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">"
  puts "<html>"
  puts "<head>"
  puts "<title>TCS: lsusb</title>"
  puts "<link rel=\"stylesheet\" href=\"style.css\" type=\"text/css\"/>"
  puts "</head>"
  puts "<body>"
  puts "<h1>TCS: lsusb</h1>"
  puts "<pre>$host</pre>"
  puts "<pre>$timestamp</pre>"
  puts "<pre>$text</pre>"
  puts "</body>"
  puts "</html>"
  
  exit 0

} message

chan configure stdout -translation "crlf"
chan configure stdout -encoding "utf-8"
puts "Status: 400 Bad Request"
puts "Content-Type: text/plain; charset=UTF-8"
puts ""
puts "error: unable to produce log text: $message"

exit 0
