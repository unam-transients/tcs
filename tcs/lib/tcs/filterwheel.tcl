########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2011, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "server"
package require "log"

if {[catch {info coroutine}]} {
  log::fatalerror "this Tcl does not have coroutines."
}

namespace eval "filterwheel" {

  variable nfilterwheels

  ######################################################################

  proc open {identifiers} {
    log::info "opening filter wheels."
    variable nfilterwheels
    set nfilterwheels [llength $identifiers]
    variable description {}
    set index 0
    while {$index < $nfilterwheels} {
      set identifier [lindex $identifiers $index]
      if {[string equal -length 4 "usb:" $identifier]} {
        set port [string range $identifier 4 end]
        if {[file exists "/sys/bus/usb/drivers/fliusb/$port"]} {
          log::info "disabling usb port $port."
          exec "/bin/sh" "-c" "echo $port >/sys/bus/usb/drivers/fliusb/unbind"
        } else {
          log::info "usb port $port is already disabled."
        }
        coroutine::after 500
      }
      incr index
    }
    set index 0
    while {$index < $nfilterwheels} {
      set identifier [lindex $identifiers $index]
      if {[string equal -length 4 "usb:" $identifier]} {
        set port [string range $identifier 4 end]
        log::info "enabling usb port $port."
        exec "/bin/sh" "-c" "echo $port >/sys/bus/usb/drivers/fliusb/bind"
      }
      coroutine::after 500
      log::info "opening filter wheel $index using $identifier."
      if {[filterwheelrawgetisopen $index]} {
        error "a filter wheel is already open."
      }
      set result [filterwheelrawopen $index $identifier]
      if {![string equal $result ok]} {
        error $result
      }
      log::info "filter wheel $index is [filterwheelrawgetvalue $index "description"]."
      lappend description [filterwheelrawgetvalue $index "description"]
      incr index
    }
    log::info "finished opening filter wheels."
    updatestatus
    return
  }

  proc close {} {
    log::info "closing filter wheels."
    variable nfilterwheels
    set index [expr {$nfilterwheels - 1}]
    while {$index >= 0} {
      checkisopen $index
      set result [filterwheelrawclose $index]
      if {![string equal $result ok]} {
        error $result
      }
      set nfilterwheels [expr {$nfilterwheels - 1}]
    }
    variable description
    set description {}
    variable maxposition
    set maxposition {}
    return
  }
  
  proc checkisopen {index} {
    if {![isopen $index]} {
      error "filter wheel $index is not currently open."
    }
  }
  
  proc isopen {index} {
    return [filterwheelrawgetisopen $index]
  }
  
  ######################################################################

  proc reset {} {
    variable nfilterwheels
    set index 0
    while {$index < $nfilterwheels} {
      set result [filterwheelrawreset $index]
      if {![string equal $result ok]} {
        error $result
      }
    }
    return
  }

  ######################################################################

  proc waitwhilemoving {} {
    log::debug "filterwheel: waiting while moving."
    variable stoppedtimestamp
    variable settledelayseconds
    if {$settledelayseconds > 0} {
      while {
        [string equal $stoppedtimestamp ""] ||
        [utcclock::diff now $stoppedtimestamp] < $settledelayseconds
      } {
        coroutine::after 100
        updatestatus
      }
    }
    log::debug "filterwheel: finished waiting while moving."
  }
  

  ######################################################################

  variable description      {}
  variable position         {}
  variable maxposition      {}
  variable ishomed          {}
  variable timestamp        {}
  variable stoppedtimestamp {}

  proc getdescription {} {
    variable description
    return $description
  }

  proc getposition {} {
    variable position
    return $position
  }

  proc getmaxposition {} {
    variable maxposition
    return $maxposition
  }
  
  proc getishomed {} {
    variable ishomed
    return $ishomed
  }

  proc updatestatus {} {
    
    variable position
    variable maxposition
    variable ishomed
    variable timestamp
    variable stoppedtimestamp
    
    variable nfilterwheels

    set index 0
    while {$index < $nfilterwheels} {
        checkisopen $index
        set result [filterwheelrawupdatestatus $index]
        if {![string equal $result "ok"]} {
          log::debug "unable to update the filter wheel status."
          return false   
        } 
        incr index
    }

    set lasttimestamp $timestamp
    set lastposition  $position

    set position    {}
    set maxposition {}
    set ishomed     {}
    set index 0
    while {$index < $nfilterwheels} {
      lappend position    [filterwheelrawgetvalue $index "position"]
      lappend maxposition [filterwheelrawgetvalue $index "maxposition"]
      lappend ishomed     [filterwheelrawgetvalue $index "ishomed"]
      incr index
    }
    
    set position    [join $position    ":"]
    set maxposition [join $maxposition ":"]
    set ishomed     [join $ishomed     ":"]

    set timestamp   [utcclock::combinedformat now]

    if {
      [string equal $position ""] ||
      [string equal $lastposition ""] || 
      ![string equal $position $lastposition]
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }

    return true

  }

  ######################################################################

  proc getpositionsingle {index} {
     variable position
     updatestatus
     set positionlist [split $position ":"]
     return [lindex $positionlist $index]
  }
  
  proc getmaxpositionsingle {index} {
     variable maxposition
     updatestatus
     set maxpositionlist [split $maxposition ":"]
     return [lindex $maxpositionlist $index]
  }
  
  proc getishomedsingle {index} {
     variable ishomed
     updatestatus
     set ishomedlist [split $ishomed ":"]
     return [lindex $ishomedlist $index]
  }
  
  ######################################################################

  proc updateloop {} {
    while {true} {
      catch {updatestatus} message
      coroutine::after 1000
    }
  }

  ######################################################################

  after idle "coroutine filterwheel::updateloopcoroutine filterwheel::updateloop"

}
