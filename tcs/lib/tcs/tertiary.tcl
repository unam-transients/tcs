########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2012, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

namespace eval "tertiary" {

  ######################################################################

  variable daytimetesting   [config::getvalue "telescope" "daytimetesting"]

  ######################################################################

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    initializehardware
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkhardwarefor "initialize"
    server::newactivitycommand "initializing" "idle" \
      tertiary::initializeactivitycommand
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkhardwarefor "reset"
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "tertiary::stopactivitycommand [server::getactivity]"
  }

  proc setport {requestedport} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "setport"
    variable daytimetesting
    setporthardware $requestedport
    return
  }

}
