########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "log"
package require "server"

package provide "enclosure" 0.0

namespace eval "enclosure" {

  ######################################################################

  variable closeexplicitly    [config::getvalue "telescope" "closeexplicitly"]
  variable opentoventilateposition [config::getvalue "enclosure" "opentoventilateposition"]
  variable openposition       [config::getvalue "enclosure" "openposition"]

  variable daytimetesting       [config::getvalue "telescope" "daytimetesting"]

  ######################################################################

  set server::datalifeseconds       30

  ######################################################################

  server::setdata "enclosure"         ""
  server::setdata "active"            false
  server::setdata "requestedposition" ""
  server::setdata "lastenclosure"     ""
  server::setdata "timestamp"         ""
  server::setdata "stoppedtimestamp"  ""

  ######################################################################
  
  proc setrequestedenclosure {enclosure} {
    server::setdata "requestedenclosure" $enclosure
  }
  
  proc setrequestedposition {position} {
    server::setdata "requestedposition" $position
  }
  
  proc checkenclosure {} {
    variable closeexplicitly
    if {
      ![string equal [server::getdata "enclosure"] [server::getdata "requestedenclosure"]]
    } {
      if {[string equal [server::getdata "requestedenclosure"] "open"]} {
        error "the enclosure did not open."
      } elseif {$closeexplicitly} {
        error "the enclosure did not close."
      }
    }
  }
  
  proc settle {} {
    log::debug "settle: settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastenclosure"    ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      log::debug "settle: wait."
      coroutine::after 1000
    }
    log::debug "settle: settled."
  }
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    setrequestedenclosure ""
    setrequestedposition ""
    dostart
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    setrequestedenclosure "closed"
    setrequestedposition 0
    doinitialize
    checkenclosure
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {position} {
    set start [utcclock::seconds]
    log::info "opening."
    setrequestedenclosure "open"
    setrequestedposition $position
    doopen $position
    checkenclosure
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    setrequestedenclosure "closed"
    setrequestedposition 0
    doclose
    checkenclosure
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::info "emergency closing."
    setrequestedenclosure "closed"
    setrequestedposition 0
    doreset
    doclose
    checkenclosure
    log::info [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    setrequestedenclosure ""
    setrequestedposition ""
    doreset
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set activity [server::getactivity]
    if {
      [string equal $activity "initializing"] || 
      [string equal $activity "opening"] || 
      [string equal $activity "closing"]
    } {
      setrequestedenclosure ""
      setrequestedposition ""
      dostop
    }
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkformove "initialize"
    server::newactivitycommand "initializing" "idle" enclosure::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] enclosure::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkforstop
    server::newactivitycommand "resetting" [server::getstoppedactivity] enclosure::resetactivitycommand
  }

  proc open {position} {
    variable openposition
    if {[string equal $position ""]} {
      set position $openposition
    }
    server::checkstatus
    server::checkactivityformove
    checkforopen
    checkposition $position
    variable daytimetesting
    if {$daytimetesting} {
        server::newactivitycommand "closing" "idle" enclosure::closeactivitycommand
    } else {
        server::newactivitycommand "opening" "idle" "enclosure::openactivitycommand $position"
    }
  }

  proc opentoventilate {} {
    variable opentoventilateposition
    open $opentoventilateposition
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    checkformove "close"
    server::newactivitycommand "closing" "idle" enclosure::closeactivitycommand
  }
  
  proc emergencyclose {} {
    server::newactivitycommand "closing" [server::getstoppedactivity] enclosure::emergencycloseactivitycommand
  }

  ######################################################################

}
