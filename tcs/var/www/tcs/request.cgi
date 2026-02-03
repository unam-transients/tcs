#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

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
umask 0; exec /usr/bin/tclsh8.6 -encoding "utf-8" "$0" ${1+"$@"}

proc request {request} {
  global prefix
  if {[string equal $request "restart"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "restart"
    return ""
  } elseif {[string equal $request "rebootcomputers"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "reboot"
    return ""
  } elseif {[string equal $request "rebootinstrument"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "rebootinstrument"
    return ""
  } elseif {[string equal $request "rebootinstrument tequila"]} {
    log::summary "about to reboot tequila." "web"
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "rebootinstrument"
    return ""
  } elseif {[string equal $request "rebootplatform"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "rebootplatform"
    return ""
  } elseif {[string equal $request "rebootmount"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "rebootmount"
    return ""
  } elseif {[string equal $request "loadblocks"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "loadblocks"
    return ""
  } elseif {[string equal $request "notifyemergency"]} {
    exec -ignorestderr "$prefix/bin/tcs" "sendpushover" "-P" "emergency" "-s" "Web Interface" "emergency" "There is an emergency."
    return ""
  } elseif {[string equal $request "emergencystop"]} {
    exec -ignorestderr "sudo" "-n" "$prefix/bin/tcs" "emergencystop"
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
  package require client
  
  log::summary "requesting \"$request\"." "web"

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
