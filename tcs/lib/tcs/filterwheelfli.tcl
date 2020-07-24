########################################################################

# This file is part of the UNAM telescope control system.

# $Id: filterwheelfli.tcl 3588 2020-05-26 23:41:05Z Alan $

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
  
  proc home {} {
    checkisopen
    variable ishomed
    set ishomed false
    while {!$ishomed} {
      log::debug "filterwheel: home: moving to the home position."
      set result [filterwheelrawhome]
      while {![string equal $result ok]} {
        log::debug "filterwheel: move: moving again to the home position."
        coroutine::after 1000
        set result [filterwheelrawhome]
      }
      coroutine::after 100
      set start [utcclock::seconds]
      while {[updatestatus] && !$ishomed && [utcclock::diff now $start] < 10} {
        log::debug "filterwheel: home: moving."
        coroutine::after 100
      }
    }
    log::debug "filterwheel: home: homed."
    coroutine::after 100
    log::debug "filterwheel: home: moving to position 0."
    variable position
    while {[updatestatus] && $position != 0} {
      log::debug "filterwheel: home: position is $position."
      coroutine::after 100
      log::debug "filterwheel: home: moving to position 0."
      set result [filterwheelrawmove 0]
      while {![string equal $result ok]} {
        log::debug "filterwheel: home: moving again to position 0."
        coroutine::after 1000
        set result [filterwheelrawmove 0]
      }
    }
    log::debug "filterwheel: home: done."
  }
    
  proc move {newposition} {
    log::debug "filterwheel: move: moving to position $newposition."
    checkisopen
    variable position
    variable maxposition
    if {[updatestatus] && $position != $newposition} {
      # FLI wheels only turns in one direction to higher position number.
      # To move to a lower position number, we have to move past 0. If
      # we are going to do this, we may as well home the wheel, which leaves
      # the wheel in position 0 and will correct any lost steps.
      if {$newposition < $position} {
        home
      }
      while {[updatestatus] && $position != $newposition} {
        # Move position by position. This is more reliable than
        # commanding a move of several positions.
        log::debug "filterwheel: move: position is $position."
        coroutine::after 100
        if {$position == $maxposition} {
          set nextposition 0
        } else {
          set nextposition [expr {$position + 1}]
        }
        log::debug "filterwheel: move: moving to position $nextposition."
        set result [filterwheelrawmove $nextposition]
        while {![string equal $result ok]} {
          log::debug "filterwheel: move: moving again to position $nextposition."
          coroutine::after 100
          set result [filterwheelrawmove $nextposition]
        }
      }
      log::debug "filterwheel: move: position is $position."
    }
    if {[updatestatus] && $position != $newposition} {
      log::warning "the filter wheel did not move correctly; position is $position."
    }
    log::info "filterwheel: move: done."
    variable stoppedtimestamp
    set stoppedtimestamp ""
    return
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "filterwheel.tcl"]
