#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: request.cgi 3579 2020-05-23 21:52:55Z Alan $

########################################################################

# Copyright © 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
umask 0; PATH=/usr/local/opt/tcl-tk/bin:$PATH exec tclsh8.6 -encoding "utf-8" "$0" ${1+"$@"}

proc request {request} {
  global prefix
  if {[string equal $request "restart"]} {
    exec "sudo" "-n" "$prefix/bin/restartsoon"
    return ""
  } elseif {[string equal $request "reboot"]} {
    exec "sudo" "-n" "$prefix/bin/rebootsoon"
    return ""
  } elseif {[string equal $request "emergencystop"]} {
    exec "sudo" "-n" "$prefix/bin/emergencystop"
    set server supervisor
    set request "disable"
  } else {
    set server [lindex $request 0]
    set request [lrange $request 1 end]
  }
  return [client::request $server $request]
}

catch {

  set scriptdir [file dirname [info script]]
  source [file join $scriptdir "cgi.tcl"]
  set query [decodequerystring]
  set request [dict get $query request]

  global prefix
  set prefix [file normalize [file join [file dirname [file normalize [info script]]] ".." ".." ".."]]
  source [file join $prefix "lib" "tcs" "packages.tcl"]

  package require log
  package require genericclient
  package require supervisorclient
  package require selectorclient
  package require executorclient
  package require telescopeclient
  
  log::info "requesting \"$request\"." "web"

  chan configure stdout -translation "crlf"
  chan configure stdout -encoding "utf-8"
  puts "Content-Type: text/plain; charset=UTF-8"
  puts ""
  if {[catch {request $request} message]} {
    puts "error: $message"
    log::error "request failed: $message" "web"
  } elseif {[string equal $message ""]} {
    log::info "request succeeded." "web"
    puts "ok"
  } else {
    log::info "request succeeded: $message" "web"
    puts "$message"
  }

  exit 0

} message

chan configure stdout -translation "crlf"
chan configure stdout -encoding "utf-8"
puts "Status: 400 Bad Request"
puts "Content-Type: text/plain; charset=UTF-8"
puts ""
puts "error: request failed: $message"

exit 0
