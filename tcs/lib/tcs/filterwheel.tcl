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

  ######################################################################

  proc open {identifier} {
    log::info "opening filter wheel $identifier."
    if {[filterwheelrawgetisopen]} {
      error "a filter wheel is already open."
    }
    set result [filterwheelrawopen $identifier]
    if {![string equal $result ok]} {
      error $result
    }
    updatestatus
    variable description
    set description [filterwheelrawgetvalue "description"]
    log::debug "filter wheel is \"$description\"."
    return
  }

  proc close {} {
    log::info "closing filter wheel."
    checkisopen
    variable description
    set description {}
    variable maxposition
    set maxposition {}
    set result [filterwheelrawclose]
    if {![string equal $result ok]} {
      error $result
    }
    return
  }
  
  proc checkisopen {} {
    if {![isopen]} {
      error "no filter wheel is currently open."
    }
  }
  
  proc isopen {} {
    return [filterwheelrawgetisopen]
  }
  
  ######################################################################

  proc reset {} {
    set result [filterwheelrawreset]
    if {![string equal $result ok]} {
      error $result
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
    
    checkisopen
    
    set result [filterwheelrawupdatestatus]
    if {![string equal $result "ok"]} {
      log::debug "unable to update the filter wheel status."
      return false   
    } 

    set lasttimestamp $timestamp
    set lastposition  $position

    set timestamp   [utcclock::combinedformat now]
    set position    [filterwheelrawgetvalue "position"]
    set maxposition [filterwheelrawgetvalue "maxposition"]
    set ishomed     [filterwheelrawgetvalue "ishomed"]

    if {$position == -1} {
      set position {}
    }

    if {
      [string equal $position ""] ||
      [string equal $lastposition ""] || 
      $position != $lastposition
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }

    return true

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
