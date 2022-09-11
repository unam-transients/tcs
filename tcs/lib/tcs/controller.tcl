########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "log"
package require "queue"

package provide "controller" 0.0

if {[catch {info coroutine}]} {
  log::fatalerror "error: this Tcl does not have coroutines."
}

namespace eval "controller" {

  ######################################################################

  variable host
  variable port
  variable translation { "auto" "binary" }
  variable connectiontype "ephemeral"
  variable statuscommand
  variable timeoutmilliseconds
  variable intervalmilliseconds
  variable statusintervalmilliseconds
  variable updatedata

  ######################################################################

  variable commandqueue [queue::create]

  proc pushcommand {command} {
    variable commandqueue
    set commandqueue [queue::push $commandqueue $command]
  }

  proc sendcommand {command} {
    pushcommand $command
    variable commandqueue
    while {[queue::search $commandqueue $command] != -1} {
      coroutine::after 10
    }
  }

  proc flushcommandqueue {} {
    variable commandqueue
    set commandqueue [queue::create]
  }

  ######################################################################

  variable channel
  variable pollmilliseconds 5

  proc openchannel {} {
    variable host
    variable port
    variable translation
    variable channel
    log::debug "controller: opening channel $host:$port."
    set channel [socket -async $host $port]
    chan configure $channel -blocking false
    chan configure $channel -buffering "line"
    chan configure $channel -encoding "ascii"
    if {![string equal "" $translation]} {
      chan configure $channel -translation $translation
    }
  }

  proc closechannel {} {
    variable channel
    log::debug "controller: closing channel."
    close $channel
  }

  variable getresponse ::gets

  proc handlecommand {command} {
    variable statuscommand
    variable channel
    variable intervalmilliseconds
    variable pollmilliseconds
    variable timeoutmilliseconds
    variable updatedata
    variable getresponse
    if {![string equal $statuscommand $command]} {
      log::debug "controller: sending command \"$command\"."
      puts -nonewline $channel $command
      flush $channel
      coroutine::after $intervalmilliseconds
    }
    if {![string equal $statuscommand ""]} {
      log::debug "controller: sending status command \"$statuscommand\"."
      puts -nonewline $channel $statuscommand
      flush $channel
    }
    set startmilliseconds [clock milliseconds]
    while {true} {
      coroutine::after $pollmilliseconds
      set response [$getresponse $channel]
      set delaymilliseconds [expr {[clock milliseconds] - $startmilliseconds}]
      if {[chan eof $channel]} {
        log::debug "controller: eof on channel."
        error "eof on controller channel."
      } elseif {[chan blocked $channel]} {
        if {$delaymilliseconds > $timeoutmilliseconds} {
          log::debug "controller: timeout on channel."
          error "timeout on controller channel."
        }
      } else {
        log::debug "controller: received response \"$response\" after $delaymilliseconds milliseconds."
        if {[$updatedata $response]} {
          break
        }
        log::debug "controller: continuing with next response."
      }
    }
  }
  
  proc drainchannel {} {
    variable channel
    variable pollmilliseconds
    variable timeoutmilliseconds
    variable getresponse
    log::debug "controller: draining channel."
    set startmilliseconds [clock milliseconds]
    while {true} {
      coroutine::after $pollmilliseconds
      set response [$getresponse $channel]
      set delaymilliseconds [expr {[clock milliseconds] - $startmilliseconds}]
      if {[chan eof $channel]} {
        break
      } elseif {[chan blocked $channel]} {
        break
      } else {
        log::debug "controller: received response \"$response\" after $delaymilliseconds milliseconds."
        log::debug "controller: ignoring controller response."
        log::debug "controller: continuing with next response."
      }
    }
  }

  ######################################################################
  
  variable initialcommand

  proc startcommandloop {{initialcommandarg ""}} {
    variable initialcommand
    set initialcommand $initialcommandarg
    after idle {
      log::debug "controller: starting commmand loop."
      coroutine controller::commandloopcoroutine controller::commandloop
    }
  }

  proc persistentcommandloop {} {
    variable commandqueue
    variable intervalmilliseconds
    variable initialcommand
    if {[catch {openchannel} message]} {
      log::debug "controller: unable to open channel: $message"
    } elseif {![string equal $initialcommand ""]} {
      handlecommand $initialcommand
    }
    while {true} {
      if {[queue::length $commandqueue] != 0} {
        set command [queue::next $commandqueue]
        if {[string equal $command ""]} {
          set commandqueue [queue::pop $commandqueue]
          server::resumeactivitycommand
        } elseif {[catch {handlecommand $command} message]} {
          log::debug "controller: unable to send command: $message"
          catch {drainchannel}
          catch {closechannel}
          if {[catch {openchannel} message]} {
            log::debug "controller: unable to open channel: $message"
          } elseif {![string equal $initialcommand ""]} {
            handlecommand $initialcommand
          }
        } else {
          if {
            [queue::length $commandqueue] != 0 &&
            [string equal $command [queue::next $commandqueue]]
          } {
            set commandqueue [queue::pop $commandqueue]
          }
          server::resumeactivitycommand
        }
      }
      coroutine::after $intervalmilliseconds
    }
  }
  
  proc ephemeralcommandloop {} {
    variable commandqueue
    variable intervalmilliseconds
    variable initialcommand
    while {true} {
      coroutine::after $intervalmilliseconds
      if {[queue::length $commandqueue] != 0} {
        set command [queue::next $commandqueue]
        if {[string equal $command ""]} {
          set commandqueue [queue::pop $commandqueue]
          server::resumeactivitycommand
          continue
        }
        if {[catch {openchannel} message]} {
          log::debug "controller: unable to open channel: $message"
          catch {drainchannel}
          catch {closechannel}
          continue
        }
        if {![string equal $initialcommand ""] && [catch {handlecommand $initialcommand} message]} {
          log::debug "controller: unable to send initial command: $message"
          catch {drainchannel}
          catch {closechannel}
          continue
        }
        if {[catch {handlecommand $command} message]} {
          log::debug "controller: unable to send command: $message"
          catch {drainchannel}
          catch {closechannel}
          continue
        } 
        if {[catch {closechannel} message]} {
          log::debug "controller: unable to close channel: $message"
          catch {drainchannel}
          continue
        }
        if {
          [queue::length $commandqueue] != 0 &&
          [string equal $command [queue::next $commandqueue]]
        } {
          set commandqueue [queue::pop $commandqueue]
        }
        server::resumeactivitycommand
      }
    }
  }
  
  proc commandloop {} {
    variable connectiontype
    if {[string equal $connectiontype "persistent"]} {
      persistentcommandloop
    } elseif {[string equal $connectiontype "ephemeral"]} {
      ephemeralcommandloop
    } else {
      log::fatalerror "controller: invalid connection type \"$connectiontype\"."
    }
  }

  ######################################################################

  variable statusloopsuspended false
  
  proc startstatusloop {} {
    after idle {
      log::debug "controller: starting status loop."
      coroutine controller::statusloopcoroutine controller::statusloop
    }
  }

  proc suspendstatusloop {} {
    variable statusloopsuspended
    set statusloopsuspended true
    return true
  }

  proc resumestatusloop {} {
    variable statusloopsuspended
    set statusloopsuspended false
    return true
  }

  proc statusloop {} {
    variable statuscommand
    variable statusintervalmilliseconds
    variable statusloopsuspended
    while {true} {
      if {!$statusloopsuspended} {
        sendcommand $statuscommand
      }
      coroutine::after $statusintervalmilliseconds
    }
  }

  ######################################################################

}
