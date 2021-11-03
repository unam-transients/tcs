########################################################################

# This file is part of the UNAM telescope control system.

# $Id: filterwheelqsi.tcl 3588 2020-05-26 23:41:05Z Alan $

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

package provide "filterwheelqsi" 0.0

load [file join [directories::prefix] "lib" "filterwheelqsi.so"] "filterwheel"

namespace eval "filterwheel" {

  variable settledelayseconds 0.5
  
  proc filterwheelrawstart {} {
    return "ok"
  }
  
  proc filterwheelrawopen {identifier} {
    if {![detector::detectorrawgetisopen]} {
      return "no detector is open."
    }
    filterwheelrawsetisopen true
    return "ok"
  }

  proc filterwheelrawclose {} {
    filterwheelrawsetisopen false
    return "ok"
  }
  
  proc filterwheelrawupdatestatus {} {
    return [detector::detectorrawfilterwheelupdatestatus]
  }
  
  proc filterwheelrawgetvalue {name} {
    return [detector::detectorrawfilterwheelgetvalue $name]
  }
  
  proc filterwheelrawmove {newposition} {
    return [detector::detectorrawfilterwheelmove $newposition]
  }
  
  proc move {newposition} {
    log::debug "filterwheel: move: moving to position $newposition."
    checkisopen
    variable position
    variable maxposition
    if {[updatestatus] && $position != $newposition} {
      log::debug "filterwheel: move: position is $position."
      set result [filterwheelrawmove $newposition]
      while {![string equal $result ok]} {
        log::info "filterwheel: move: moving again to position $newposition."
        coroutine::after 100
        set result [filterwheelrawmove $newposition]
      }
    }
    if {[updatestatus] && $position != $newposition} {
      log::warning "the filter wheel did not move correctly; position is $position."
    }
    log::debug "filterwheel: move: done."
    variable stoppedtimestamp
    set stoppedtimestamp ""
    return
  }

}

source [file join [directories::prefix] "lib" "tcs" "filterwheel.tcl"]
