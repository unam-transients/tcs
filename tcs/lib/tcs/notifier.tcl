########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
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

package require "client"
package require "coroutine"
package require "server"
package require "utcclock"

package provide "notifier" 0.0

namespace eval "notifier" {

  variable servers [concat \
    [config::getvalue "notifier" "monitoredservers"] \
    [config::getvalue "instrument" "monitoreddetectors"] \
  ]
  variable problemtoleranceseconds [config::getvalue "notifier" "problemtoleranceseconds"]

  ######################################################################

  variable problemservers   {}
  variable problemtimestamp ""
  variable problemnotified false
  
  ######################################################################

  server::setdata "servers"          $servers
  server::setdata "problemservers"   {}
  server::setdata "problemtimestamp" ""
  server::setdata "timestamp"        [utcclock::combinedformat "now"]

  ######################################################################
  
  proc notify {} {

    variable problemservers
    variable problemtimestamp

    log::warning [format \
      "persistent problems since %s with: %s" \
      [utcclock::format $problemtimestamp 0] [join $problemservers " "] \
    ]

    set message [format \
      "notifier: persistent problems since %s with: %s" \
      [utcclock::format $problemtimestamp 0] [join $problemservers " "] \
    ]
    exec "[directories::prefix]/bin/tcs" "sendpushover" \
      "-P" "emergency" \
      "-s" "Notifier" \
      "emergency" "$message"

  }
  
  ######################################################################
  
  proc monitorservers {} {
  
    variable servers
    variable problemtoleranceseconds
    variable problemservers
    variable problemtimestamp
    variable problemnotified
    
    set lastproblemservers $problemservers

    set problemservers {}
    foreach server $servers {

      if {[catch {client::update $server}]} {
        log::info "$server: no response to update."
        lappend problemservers $server
        continue
      }
      
      set status [client::getstatus $server]
      if {![string equal $status "ok"]} {
        log::info "$server: status is $status."
        lappend problemservers $server
        continue
      }

      set activity [client::getdata $server "activity"]
      if {[string equal $activity "error"]} {
        log::info "$server: activity is $activity."
        lappend problemservers $server
        continue
      }
        
    }
    
    if {[llength $problemservers] == 0} {
      if {[llength $lastproblemservers] > 0} {
        log::info "no servers have problems."
      }
      set problemtimestamp ""
    } else {
      if {[llength $lastproblemservers] == 0} {
        set problemtimestamp [utcclock::combinedformat "now"]
      }
      log::info [format \
        "problems since %s with: %s" \
        [utcclock::format $problemtimestamp 0] [join $problemservers " "] \
      ]
    }
    
    server::setdata "servers"          $servers
    server::setdata "problemservers"   $problemservers
    server::setdata "problemtimestamp" $problemtimestamp
    server::setdata "timestamp"        [utcclock::combinedformat "now"]

    if {[llength $problemservers] == 0} {
      set problemnotified false
    } elseif {[utcclock::diff now $problemtimestamp] > $problemtoleranceseconds} {
      if {!$problemnotified} {
        notify
        set problemnotified true
      }
    }


  }

  ######################################################################

  set server::datalifeseconds 120

  proc start {} {
    server::setrequestedactivity "idle"
    server::setactivity "idle"
    server::setstatus "ok"
    coroutine::every 30000 notifier::monitorservers
  }

}
