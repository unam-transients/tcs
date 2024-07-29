########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "louvers" 0.0

namespace eval "louvers" {

  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedlouvers"  ""
  server::setdata "louvers"           ""
  server::setdata "timestamp"        ""

  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    updatedata
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "closed"
    log::info "closing louvers."
    closehardware
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc openactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "open"
    log::info "opening louvers."
    openhardware
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "closed"
    log::info "closing louvers."
    closehardware
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "opening" "idle" louvers::openactivitycommand
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "closing" "idle" louvers::closeactivitycommand
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" louvers::initializeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 louvers::updatedata
    server::newactivitycommand "starting" "started" louvers::startactivitycommand
  }

}
