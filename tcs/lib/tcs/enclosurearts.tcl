########################################################################

# This file is part of the UNAM telescope control system.

# $Id: enclosurearts.tcl 3601 2020-06-11 03:20:53Z Alan $

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
package require "controller"
package require "log"
package require "server"

package provide "enclosurearts" 0.0

namespace eval "enclosure" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "enclosure" "controllerhost"]
  variable controllerport [config::getvalue "enclosure" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "\$016\r"
  set controller::timeoutmilliseconds         5000
  set controller::intervalmilliseconds        500
  set controller::updatedata                  enclosure::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  variable settledelayseconds 5

  ######################################################################

  server::setdata "inputchannels"     ""
  server::setdata "outputchannels"    ""
  server::setdata "mode"              ""
  server::setdata "errorflag"         ""
  server::setdata "motorcurrentflag"  ""
  server::setdata "rainsensorflag"    ""
  server::setdata "safetyrailflag"    ""
  server::setdata "emergencystopflag" ""

  proc isignoredcontrollerresponseresponse {response} {
    switch -- $response {
      ">" {
        return true
      }
      default {
        return false
      }
    }
  }

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    set controllerresponse [string trim $controllerresponse]
    if {[isignoredcontrollerresponseresponse $controllerresponse]} {
      return false
    }

    if {[scan $controllerresponse "!%2x%2x00" outputchannels inputchannels] != 2} {
      error "invalid response: \"$controllerresponse\"."
    }
    
    log::debug [format "input channels = %02x output channels = %02x" $inputchannels $outputchannels] 

    switch -- [expr {($inputchannels >> 0) & 3}] {
      0 { set enclosure "intermediate" }
      1 { set enclosure "open" }
      2 { set enclosure "closed" }
      3 { set enclosure "error" }
    }

    set lasterrorflag [server::getdata "errorflag"]
    set lastmode      [server::getdata "mode"]
    switch -- [expr {($inputchannels >> 3) & 1}] {
      0 { 
        set mode "local"
        set errorflag "unreliable"
      }
      1 { 
        set mode "remote" 
        switch -- [expr {($inputchannels >> 2) & 1}] {
          0 { set errorflag "ok" }
          1 { set errorflag "error" }
        }
      }
    }
    if {
      ![string equal $lastmode ""] &&
      ![string equal $lastmode $mode]
    } {
      log::warning "mode has changed from \"$lastmode\" to \"$mode\"."
    }
    if {
      ![string equal $lasterrorflag ""] &&
      ![string equal $lasterrorflag $errorflag]
    } {
      log::warning "error flag has changed from \"$lasterrorflag\" to \"$errorflag\"."
    }

    set lastmotorcurrentflag [server::getdata "motorcurrentflag"]
    switch -- [expr {($inputchannels >> 4) & 1}] {
      0 { set motorcurrentflag "ok" }
      1 { set motorcurrentflag "error" }
    }
    if {
      ![string equal $lastmotorcurrentflag ""] &&
      ![string equal $lastmotorcurrentflag $motorcurrentflag]
    } {
      log::warning "motor current flag has changed from \"$lastmotorcurrentflag\" to \"$motorcurrentflag\"."
    }

    set lastrainsensorflag [server::getdata "rainsensorflag"]
    switch -- [expr {($inputchannels >> 5) & 1}] {
      0 { set rainsensorflag "ok" }
      1 { set rainsensorflag "error" }
    }
    if {
      ![string equal $lastrainsensorflag ""] &&
      ![string equal $lastrainsensorflag $rainsensorflag]
    } {
      log::warning "rain sensor flag has changed from \"$lastrainsensorflag\" to \"$rainsensorflag\"."
    }

    set lastsafetyrailflag [server::getdata "safetyrailflag"]
    switch -- [expr {($inputchannels >> 6) & 1}] {
      0 { set safetyrailflag "ok" }
      1 { set safetyrailflag "error" }
    }
    if {
      ![string equal $lastsafetyrailflag ""] &&
      ![string equal $lastsafetyrailflag $safetyrailflag]
    } {
      log::warning "safety rail flag has changed from \"$lastsafetyrailflag\" to \"$safetyrailflag\"."
    }

    set lastemergencystopflag [server::getdata "emergencystopflag"]
    switch -- [expr {($inputchannels >> 7) & 1}] {
      0 { set emergencystopflag "ok" }
      1 { set emergencystopflag "error" }
    }
    if {
      ![string equal $lastemergencystopflag ""] &&
      ![string equal $lastemergencystopflag $emergencystopflag]
    } {
      log::warning "emergency stop flag has changed from \"$lastemergencystopflag\" to \"$emergencystopflag\"."
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
    server::setdata "inputchannels"     [format "%02X: %08b" $inputchannels $inputchannels]
    server::setdata "outputchannels"    [format "%02X: %08b" $outputchannels $outputchannels]
    server::setdata "enclosure"         $enclosure
    server::setdata "lastenclosure"     $lastenclosure
    server::setdata "mode"              $mode
    server::setdata "errorflag"       $errorflag
    server::setdata "motorcurrentflag"  $motorcurrentflag
    server::setdata "rainsensorflag"    $rainsensorflag
    server::setdata "safetyrailflag"    $safetyrailflag
    server::setdata "emergencystopflag" $emergencystopflag
    server::setdata "stoppedtimestamp"  $stoppedtimestamp
    server::setdata "settled"           $settled
    
    if {
      [string equal $errorflag "error"] &&
      ![string equal [server::getdata "activity"] "starting"] &&
      ![string equal [server::getdata "activity"] "resetting"] &&
      ![string equal [server::getdata "activity"] "error"]
    } {
      log::error "the controller error flag is set."
      server::setactivity "error"
    }

    return true
  }

  ######################################################################
  
  proc dostart {} {
    controller::sendcommand "#010000\n"
  }
  
  proc doinitialize {} {
    controller::sendcommand "#010004\n"
    controller::sendcommand "#010002\n"
    settle
    controller::sendcommand "#010000\n"
  }
  
  proc doopen {position} {
    if {$position == 60 || $position == 120} {
      # We can't move directly from a larger to a smaller position. So, we
      # close first. Strictly speaking, this is not necessary if we move
      # from 60 to 120, but it doesn't seem worthwhile to optimize this case.
      controller::sendcommand "#010002\n"
      settle
    }
    if {$position == 60} {
      set selector [expr 0x08]
    } elseif {$position == 120} {
      set selector [expr 0x20]
    } else {
      set selector [expr 0x00]
    }
    controller::sendcommand [format "#0100%02X\n" [expr {$selector | 1}]]
    settle
    controller::sendcommand [format "#0100%02X\n" [expr {$selector | 0}]]
  }
  
  proc doclose {} {
    controller::sendcommand "#010002\n"
    settle
    controller::sendcommand "#010000\n"
  }
  
  proc doreset {} {
    controller::flushcommandqueue
    controller::sendcommand "#010004\n"
    controller::sendcommand "#010000\n"
  }
  
  proc dostop {} {
    controller::flushcommandqueue
    controller::sendcommand "#010000\n"
  }
  
  ######################################################################
  
  proc checkposition {position} {
    if {
      ![string is integer -strict $position] || 
      ($position != 60 && $position != 120 && $position != 180)
    } {
      error "invalid position \"$position\"."
    }
  }
  
  proc checkremote {} {
    if {![string equal [server::getdata "mode"] "remote"]} {
      error "the enclosure controller is not in remote mode."
    }
  }

  proc checkrainsensor {} {
    if {![string equal [server::getdata "rainsensorflag"] "ok"]} {
      error "the enclosure rain sensor is not ok."
    }
  }
  
  proc checkformove {type} {
    checkremote
    if {![string equal $type "open"] && ![string equal [server::getdata "safetyrailflag"] "ok"]} {
      error "the enclosure safety rail is not ok."
    }
    if {![string equal [server::getdata "emergencystopflag"] "ok"]} {
      error "the enclosure emergency stop is not ok."
    }
    if {![string equal [server::getdata "motorcurrentflag"] "ok"]} {
      error "the enclosure motor current is not ok."
    }
    if {![string equal [server::getdata "errorflag"] "ok"]} {
      error "the enclosure controller has an error."
    }
  }
  
  proc checkforstop {} {
    checkremote
  }
  
  proc checkforopen {} {
    checkformove "open"
    checkrainsensor
  }
  
  ######################################################################

  proc start {} {
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" enclosure::startactivitycommand
  }

}

source [file join [directories::prefix] "lib" "tcs" "enclosure.tcl"]
