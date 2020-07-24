########################################################################

# This file is part of the UNAM telescope control system.

# $Id: enclosureplc.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package require "config"
package require "client"
package require "log"
package require "server"

package provide "enclosureplc" 0.0

namespace eval "enclosure" {

  variable svnid {$Id}

  ######################################################################

  variable settledelayseconds 10

  ######################################################################

  proc updatedata {} {

    set timestamp [utcclock::combinedformat now]

    if {[catch {client::update "plc"}]} {
      log::debug "enclosure: unable to update the plc data."
      set roof   ""
      set door   ""
    } else {
      set roof   [client::getdata "plc" "roof"  ]
      set door   [client::getdata "plc" "door"  ]
    }
    log::debug "roof = \"$roof\"."
    log::debug "door = \"$door\"."
    
    if {[string equal $roof ""] && [string equal $door ""]} {
      set enclosure ""
    } elseif {[string equal $roof "open"] && [string equal $door "open"]} {
      set enclosure "open"
    } elseif {[string equal $roof "closed"] && [string equal $door "closed"]} {
      set enclosure "closed"
    } else {
      set enclosure "intermediate"
    }

    set lasttimestamp    [server::getdata "timestamp"]
    set lastenclosure    [server::getdata "enclosure"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]

    if {![string equal $enclosure $lastenclosure] || [string equal $enclosure "intermediate"]} {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }
    variable settledelayseconds
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      set settled true
    } else {
      set settled false
    }
    
    server::setstatus "ok"
    server::setdata "timestamp"         $timestamp
    server::setdata "lasttimestamp"     $lasttimestamp
    server::setdata "enclosure"         $enclosure
    server::setdata "lastenclosure"     $lastenclosure
    server::setdata "stoppedtimestamp"  $stoppedtimestamp
    server::setdata "settled"           $settled
    
  }

  ######################################################################
  
  proc dostart {} {
  }
  
  proc doinitialize {} {
    doclose
  }
  
  proc doopen {position} {
    if {[catch {client::request "plc" "open"}]} {
      error "request to PLC failed."
    }
    settle
  }
  
  proc doclose {} {
    variable closeexplicitly
    if {$closeexplicitly} {
      if {[catch {client::request "plc" "close"}]} {
        error "request to PLC failed."
      }
      settle
    }
  }
  
  proc doreset {} {
  }
  
  proc dostop {} {
  }
  
  ######################################################################
  
  proc checkposition {position} {
  }

  proc checkforstop {} {
  }

  proc checkformove {} {
  }
  
  proc checkforopen {} {
  }

  ######################################################################

  proc start {} {
    coroutine::every 1000 enclosure::updatedata
    server::newactivitycommand "starting" "started" enclosure::startactivitycommand
  }

}

source [file join [directories::prefix] "lib" "tcs" "enclosure.tcl"]
