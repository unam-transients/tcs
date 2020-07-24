########################################################################

# This file is part of the UNAM telescope control system.

# $Id: coversastelco.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "controller"
package require "log"
package require "server"

package provide "coversastelco" 0.0

namespace eval "covers" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "covers" "controllerhost"]
  variable controllerport [config::getvalue "covers" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "\$016\r"
  set controller::timeoutmilliseconds         5000
  set controller::intervalmilliseconds        500
  set controller::updatedata                  covers::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "requestedcovers"  ""
  server::setdata "covers"           ""
  server::setdata "mode"             ""
  server::setdata "timestamp"        [utcclock::combinedformat now]
  server::setdata "settled"          false
  server::setdata "stoppedtimestamp" [utcclock::combinedformat now]
  server::setdata "inputchannels"     ""
  server::setdata "outputchannels"    ""

  variable settledelayseconds 1

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {
      [string equal $controllerresponse ">"]
    } {
      return false
    }
    
    if {[scan $controllerresponse "!%2x%2x00" outputchannels inputchannels] != 2} {
      error "invalid controller response \"$controllerresponse\"."
    }
    
    log::debug [format "input channels = %02x output channels = %02x" $outputchannels $inputchannels] 

    if {$inputchannels & 1} {
      set open true
    } else {
      set open false
    }
    if {$inputchannels & 2} {
      set closed true
    } else {
      set closed false
    }
    if {$inputchannels & 8} {
      set mode "remote"
    } else {
      set mode "local"
    }
    
    if {$open} {
      set covers "open"
    } elseif {$closed} {
      set covers "closed"
    } else {
      set covers "intermediate"
    }
    
    set lasttimestamp    [server::getdata "timestamp"]
    set lastcovers       [server::getdata "covers"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]

    if {![string equal $covers $lastcovers] || [string equal $covers "intermediate"]} {
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
    server::setdata "timestamp"        $timestamp
    server::setdata "covers"           $covers
    server::setdata "mode"             $mode
    server::setdata "inputchannels"    [format "%02X: %08b" $inputchannels $inputchannels]
    server::setdata "outputchannels"   [format "%02X: %08b" $outputchannels $outputchannels]
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled
    
    return true
  }

  ######################################################################
  
  proc stopcovers {} {
    server::setdata "requestedcovers" ""
    controller::sendcommand "#010000\r"
  }
  
  proc opencovers {} {
    server::setdata "requestedcovers" "open"
    controller::sendcommand "#010001\r"
    settle
    controller::sendcommand "#010000\r"
    if {![string equal [server::getdata "covers"] "open"]} {
      error "the covers did not open."
    }
  }
  
  proc closecovers {} {
    server::setdata "requestedcovers" "closed"
    controller::sendcommand "#010002\r"
    settle
    controller::sendcommand "#010000\r"
    if {![string equal [server::getdata "covers"] "closed"]} {
      error "the covers did not close."
    }
  }
  
  ######################################################################

  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    stopcovers
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    opencovers
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set activity [server::getdata "activity"]
    if {
      [string equal $activity "initializing"] || 
      [string equal $activity "opening"] || 
      [string equal $activity "closing"]
    } {    
      stopcovers
    }
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
