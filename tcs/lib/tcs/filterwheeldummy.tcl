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

package provide "filterwheeldummy" 0.0

load [file join [directories::prefix] "lib" "filterwheeldummy.so"] "filterwheel"

namespace eval "filterwheel" {
  
  variable settledelayseconds 0
  
  proc filterwheelrawstart {} {
    return "ok"
  }

  proc home {} {
  }
    
  proc move {newposition} {
    log::debug "filterwheel: move: moving to position $newposition."
    variable position
    variable maxposition
    variable nfilterwheels
    set newpositionlist [split $newposition ":"]
    if {[llength $newpositionlist] != $nfilterwheels} {
      error "invalid filter position \"$newposition\"."
    }
    set index 0
    while {$index < $nfilterwheels} {
      if {[lindex $newpositionlist $index] >= [getmaxpositionsingle $index]} {
        error "invalid filter position \"$newposition\"."
      }
      incr index
    }
    set index 0
    while {$index < $nfilterwheels} {
      log::debug "filterwheel: move: moving filter wheel $index"
      checkisopen $index
      set result [filterwheelrawmove $index [lindex $newpositionlist $index]]
      if {![string equal $result "ok"]} {
        log::warning "filter wheel $index did not move correctly: $result"
      }
      if {[getpositionsingle $index] != [lindex $newpositionlist $index]} {
        log::warning "filter wheel $index did not move correctly and its position is [getpositionsingle $index]."
      }
      incr index
    }
    log::debug "filterwheel: move: done."
    variable stoppedtimestamp
    set stoppedtimestamp ""
    return
  }

}

source [file join [directories::prefix] "lib" "tcs" "filterwheel.tcl"]
