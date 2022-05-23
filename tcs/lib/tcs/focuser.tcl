########################################################################

# This file is part of the UNAM telescope control system.

# $Id: focuser.tcl 3588 2020-05-26 23:41:05Z Alan $

########################################################################

# Copyright © 2011, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

namespace eval "focuser" {

  variable svnid {$Id}

  ######################################################################

  variable opened false  

  proc opened {} {
    variable opened
    return $opened
  }
  
  proc setopened {value} {
    variable opened
    set opened $value
  }

  ######################################################################

  proc open {identifier} {
    log::info "opening focuser $identifier."
    if {[opened]} {
      error "a focuser is already open."
    }
    set result [openspecific $identifier]
    if {![string equal $result ok]} {
      error $result
    }
    setopened true
    variable description
    set description [focuserrawgetdescription]
    log::debug "focuser is \"$description\"."
    variable minposition
    set minposition [focuserrawgetminposition]
    log::debug "focuser min position is $minposition."
    variable maxposition
    set maxposition [focuserrawgetmaxposition]
    log::debug "focuser max position is $maxposition."
    return
  }

  proc close {} {
    log::info "closing focuser."
    if {![opened]} {
      error "no focuser is open."
    }
    setopened false
    variable description
    set description {}
    variable focusermaxposition
    set focusermaxposition {}
    set result [focuserrawclose]
    if {![string equal $result ok]} {
      error $result
    }
    return
  }

  proc move {position} {
    log::debug "moving the focuser to $position."
    if {![opened]} {
      error "no focuser is open."
    }
    variable minposition
    variable maxposition
    if {$position < $minposition || $position > $maxposition} {
      error "requested position \"$position\" is out of range."
    }
    set result [focuserrawenable]
    if {![string equal $result ok]} {
      error $result
    }
    set result [focuserrawmove $position]
    if {![string equal $result ok]} {
      error $result
    }
    variable stoppedtimestamp
    set stoppedtimestamp ""
    return
  }
  
  proc waitwhilemoving {} {
    log::debug "focuser: waiting while moving."
    variable stoppedtimestamp
    variable settledelayseconds
    if {$settledelayseconds > 0} {
      while {
        [string equal $stoppedtimestamp ""] ||
        [utcclock::diff now $stoppedtimestamp] < $settledelayseconds
      } {
        coroutine::after 100
      }
    }
    set result [focuserrawdisable]
    if {![string equal $result ok]} {
      error $result
    }
    log::debug "focuser: finished waiting while moving."
  }
  
  ######################################################################

  variable description      {}
  variable position         {}
  variable minposition      {}
  variable maxposition      {}
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

  proc getminposition {} {
    variable minposition
    return $minposition
  }

  proc getmaxposition {} {
    variable maxposition
    return $maxposition
  }
  
  proc setposition {position} {
    log::debug "setting the focuser to $position."
    if {![opened]} {
      error "no focuser is open."
    }
    variable minposition
    variable maxposition
    if {$position < $minposition || $position > $maxposition} {
      error "requested position \"$position\" is out of range."
    }
    set result [focuserrawsetposition $position]
    if {![string equal $result ok]} {
      error $result
    }
    variable stoppedtimestamp
    set stoppedtimestamp ""
    return
  }

  proc update {} {
    
    variable position
    variable timestamp
    variable stoppedtimestamp
    
    if {![opened]} {
      error "no focuser opened."
    }
    
    set lasttimestamp $timestamp
    set lastposition  $position

    set result [focuserrawupdateposition]
    if {[string equal $result "ok"]} {
      set position [focuserrawgetposition]
    } else {
      set position {}
      log::debug "unable to update the focuser position."      
    }
    set timestamp [utcclock::combinedformat now]
    
    if {
      [string equal $position ""] ||
      [string equal $lastposition ""] || 
      $position != $lastposition
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }

  }

  ######################################################################

}
