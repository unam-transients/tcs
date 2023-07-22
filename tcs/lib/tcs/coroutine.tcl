########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2013, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "coroutine" 0.0

if {[catch {info coroutine}]} {
  error "coroutines are not present."
}

namespace eval "coroutine" {

  proc incoroutine {} {
    if {[string equal "" [info coroutine]]} {
      return false
    } else {
      return true
    }
  }

  variable id 0

  proc create {command {args}} {
    variable id
    incr id
    set coroutine [eval ::coroutine $id $command $args]
    return $coroutine
  }
  
  proc destroy {coroutine} {
    rename $coroutine {}
  }

  proc after {milliseconds} {
    if {![incoroutine]} {
      ::after $milliseconds
    } else {
      set start [clock milliseconds]
      while {true} {
        set now [clock milliseconds]
        if {$now >= $start + $milliseconds} {
          return
        }
        set remaining [expr {$start + $milliseconds - $now}]
        ::after $remaining [info coroutine]
        yield
      }
    }
  }

  proc every {milliseconds command {args}} {
    create eval "while {true} {
      eval $command $args
      coroutine::after $milliseconds
    }"
  }
  
  proc afterandevery {milliseconds command {args}} {
    create eval "while {true} {
      coroutine::after $milliseconds
      eval $command $args
    }"
  }
  
  proc yield {} {
    ::yield
  }
  
  proc gets {channel {timeout 0} {interval 10}} {
    if {![incoroutine]} {
      if {![chan configure $channel -blocking]} {
        chan configure $channel -blocking true
      }
      return [::gets $channel]
    } else {
      if {[chan configure $channel -blocking]} {
        chan configure $channel -blocking false
      }
      set start [clock milliseconds]
      while true {
        set result [::gets $channel]
        if {![fblocked $channel]} {
          return $result
        }
        set now [clock milliseconds]
        if {$timeout > 0 && $now > $start + $timeout} {
          error "no line read before timeout."
        }
        after $interval
      }
    }
  }
  
  proc read {channel length {timeout 0} {interval 10}} {
    if {![incoroutine]} {
      if {![chan configure $channel -blocking]} {
        chan configure $channel -blocking true
      }
      return [::read $channel $length]
    } else {
      if {[chan configure $channel -blocking]} {
        chan configure $channel -blocking false
      }
      set start [clock milliseconds]
      while true {
        set result [::read $channel $length]
        if {[string length $result] == $length || [eof $channel]} {
          return $result
        }
        set now [clock milliseconds]
        if {$timeout > 0 && $now > $start + $timeout} {
          error "insufficient data read before timeout."
        }
        after $interval
      }
    }
  }
  
  proc start {} {
    vwait forever
  }

}
