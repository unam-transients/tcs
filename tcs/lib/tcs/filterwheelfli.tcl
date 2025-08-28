########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "filterwheelfli" 0.0

load [file join [directories::prefix] "lib" "filterwheelfli.so"] "filterwheel"

namespace eval "filterwheel" {
  
  variable settledelayseconds 0.5

  proc filterwheelrawstart {} {
    if {[catch {exec "sudo" "/sbin/modprobe" "fliusb" "buffersize=4194304"}]} {
      error "unable to load the fliusb kernel module."
    }
    foreach file [glob "/dev/fliusb*"] {
      if {[catch {exec "sudo" "/bin/chmod" "a=rw" "$file"}]} {
        error "unable to change the permissions of $file."
      }    
    }  
  }
  
  proc movesingle {index newposition} {
    log::debug "filterwheel: movesingle: moving filter wheel $index to $newposition."
    variable position
    variable maxposition
    if {[getpositionsingle $index] != $newposition} {
      # FLI wheels only turns in one direction to higher position number. To
      # move to a lower position number, we have to move past 0. If we are going
      # to do this, we may as well home the wheel, which will correct any lost
      # steps.
      log::debug "filterwheel: movesingle: ishomed is [getishomedsingle $index]."
      if {$newposition < [getpositionsingle $index]} {
        homesingle $index
      }
      log::debug "filterwheel: movesingle: moving to position $newposition."
      set result [filterwheelrawmove $index $newposition]
      while {![string equal $result ok]} {
        log::debug "filterwheel: movesingle: move: moving again to position $newposition."
        coroutine::after 100
        set result [filterwheelrawmove $index $newposition]
      }
      log::debug "filterwheel: movesingle: position is [getpositionsingle $index]."
    }
    if {[getpositionsingle $index]!= $newposition} {
      log::warning "filter wheel $index did not move correctly and its position is [getpositionsingle $index]."
    }
  }

  proc homesingle {index} {
    log::debug "filterwheel $index: home: start."
    checkisopen $index
    variable ishomed
    set first true
    while {$first || ![getishomedsingle $index]} {
      set first false
      log::debug "filterwheel $index: home: moving to the home position."
      set result [filterwheelrawhome $index]
      while {![string equal $result ok]} {
        log::debug "filterwheel $index: move: moving again to the home position."
        coroutine::after 1000
        set result [filterwheelrawhome $index]
      }
      coroutine::after 100
      set start [utcclock::seconds]
      while {[updatestatus] && ![getishomedsingle $index] && [utcclock::diff now $start] < 10} {
        log::debug "filterwheel $index: home: moving."
        coroutine::after 100
      }
    }
    log::debug "filterwheel $index: home: settling."
    coroutine::after 1000
    log::debug "filterwheel $index: home: done."
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "filterwheel.tcl"]
