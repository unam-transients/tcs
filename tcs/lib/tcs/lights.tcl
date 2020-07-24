########################################################################

# This file is part of the UNAM telescope control system.

# $Id: lights.tcl 3594 2020-06-10 14:55:51Z Alan $

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

package provide "lights" 0.0

namespace eval "lights" {

  variable svnid {$Id}
  
  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedlights"  ""
  server::setdata "lights"           ""
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
    set requestedlights [server::getdata "requestedlights"]
    log::info "switching $requestedlights."
    switchrequested
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc switchactivitycommand {} {
    set start [utcclock::seconds]
    set requestedlights [server::getdata "requestedlights"]
    log::info "switching $requestedlights."
    switchrequested
    log::info [format "finished switching $requestedlights after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedlights" "on"
    server::newactivitycommand "switching" "idle" lights::switchactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedlights" "off"
    server::newactivitycommand "switching" "idle" lights::switchactivitycommand
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::setdata "requestedlights" "off"
    server::newactivitycommand "initializing" "idle" lights::initializeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 lights::updatedata
    server::newactivitycommand "starting" "idle" lights::startactivitycommand
  }

}
