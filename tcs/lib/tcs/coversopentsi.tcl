########################################################################

# This file is part of the UNAM telescope control system.

# $Id: coverscoatlioan.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "controller"
package require "log"
package require "server"

config::setdefaultvalue "covers" "controllerport" "65432"
config::setdefaultvalue "covers" "controllerhost" "mount"

package provide "coversopentsi" 0.0

namespace eval "covers" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "covers" "controllerhost"]
  variable controllerport [config::getvalue "covers" "controllerport"]

  ######################################################################

  server::setdata "requestedcovers"  ""
  server::setdata "covers"           ""
  server::setdata "port2cover"       ""
  server::setdata "port3cover"       ""
  server::setdata "timestamp"        [utcclock::combinedformat now]
  server::setdata "settled"          false
  server::setdata "stoppedtimestamp" [utcclock::combinedformat now]

  variable settledelayseconds 1

  ######################################################################

  # We use command identifiers 1 for status command, 2 for emergency
  # stop, and 3-99 for normal commands,

  variable statuscommandidentifier        1
  variable emergencystopcommandidentifier 2
  variable firstnormalcommandidentifier   3
  variable lastnormalcommandidentifier    99

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::statuscommand "$statuscommandidentifier GET [join {
    TELESCOPE.READY_STATE
    AUXILIARY.COVER.REALPOS
    AUXILIARY.PORT_COVER[2].REALPOS
    AUXILIARY.PORT_COVER[3].REALPOS
  } ";"]\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::updatedata                  covers::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [regexp {TPL2 .*} $controllerresponse] == 1 ||
      [regexp {AUTH OK .*} $controllerresponse] == 1 ||
      [regexp {^[0-9]+ COMMAND OK}  $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $controllerresponse] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $controllerresponse] == 1
    }
  }

  variable pendingmode
  variable pendingcovers
  variable pendingport2cover
  variable pendingport3cover

  proc updatecontrollerdata {controllerresponse} {

    variable pendingmode
    variable pendingcovers
    variable pendingport2cover
    variable pendingport3cover

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]
    
    if {[isignoredcontrollerresponse $controllerresponse]} {
      return false
    }

    if {
      [regexp {^[0-9]+ EVENT ERROR } $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA ERROR } $controllerresponse] == 1
    } {
      log::warning "controller error: \"$controllerresponse\"."
      return false
    }

    if {![scan $controllerresponse "%d " commandidentifier] == 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }

    variable statuscommandidentifier
    variable emergencystopcommandidentifier
    variable completedcommandidentifier

    if {$commandidentifier == $emergencystopcommandidentifier} {
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        finishemergencystop
        return false
      }
    }

    if {$commandidentifier != $statuscommandidentifier} {
      variable currentcommandidentifier
      variable completedcurrentcommand
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        log::debug [format "controller command %d completed." $commandidentifier]
        if {$commandidentifier == $currentcommandidentifier} {
          log::debug "current controller command completed."
          set completedcurrentcommand true
        }
      }
      return false
    }

    #log::debug "status: controller response \"$controllerresponse\"."
    if {[scan $controllerresponse "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      if {$value == -3.0} {
        set pendingmode "local"
      } elseif {$value == -2.0} {
        set pendingmode "emergencystop"
      } elseif {$value == -1.0} {
        set pendingmode "blocked"
      } elseif {$value == 0.0} {
        set pendingmode "off"
      } elseif {$value == 1.0} {
        set pendingmode "on"
      } else {
        set pendingmode "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.COVER.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set pendingcovers "closed"
      } elseif {$value == 1.0} {
        set pendingcovers "open"
      } else {
        set pendingcovers "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.PORT_COVER\[2\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set pendingport2cover "closed"
      } elseif {$value == 1.0} {
        set pendingport2cover "open"
      } else {
        set pendingport2cover "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.PORT_COVER\[3\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set pendingport3cover "closed"
      } elseif {$value == 1.0} {
        set pendingport3cover "open"
      } else {
        set pendingport3cover "intermediate"
      }
      return false
    }

    if {[regexp {[0-9]+ DATA INLINE } $controllerresponse] == 1} {
      log::debug "status: ignoring DATA INLINE response."
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $controllerresponse] != 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }
    
    set mode       $pendingmode
    set covers     $pendingcovers
    set port2cover $pendingport2cover
    set port3cover $pendingport3cover

    set timestamp [utcclock::combinedformat "now"]

    set lasttimestamp    [server::getdata "timestamp"]
    set lastcovers       [server::getdata "covers"]
    set lastport2cover   [server::getdata "port2cover"]
    set lastport3cover   [server::getdata "port3cover"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]

    if {
      ![string equal $covers     $lastcovers    ] || [string equal $covers     "intermediate"] ||
      ![string equal $port2cover $lastport2cover] || [string equal $port2cover "intermediate"] ||
      ![string equal $port3cover $lastport3cover] || [string equal $port3cover "intermediate"]
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }
    variable settledelayseconds
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      set settled true
    } else {
      set settled false
    }
    
    server::setstatus "ok"
    server::setdata "timestamp"        $timestamp
    server::setdata "mode"             $mode
    server::setdata "covers"           $covers
    server::setdata "port2cover"       $port2cover
    server::setdata "port3cover"       $port3cover
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled

    server::setstatus "ok"

    return true
  }

  ######################################################################
  
  proc stopcovers {} {
    server::setdata "requestedcovers" ""
    #controller::sendcommand "#010000\r"
  }
  
  proc opencovers {} {
    server::setdata "requestedcovers" "open"
    #controller::sendcommand "#010001\r"
    settle
    #controller::sendcommand "#010000\r"
    if {![string equal [server::getdata "covers"] "open"]} {
      error "the covers did not open."
    }
  }
  
  proc closecovers {} {
    server::setdata "requestedcovers" "closed"
    #controller::sendcommand "#010002\r"
    settle
    #controller::sendcommand "#010000\r"
    if {![string equal [server::getdata "covers"] "closed"]} {
      error "the covers did not close."
    }
  }
  
  ######################################################################

  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    stopcovers
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    opencovers
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set activity [server::getdata "activity"]
    if {
      [string equal $activity "initializing"] || 
      [string equal $activity "opening"] || 
      [string equal $activity "closing"]
    } {    
      stopcovers
    }
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc start {} {
    server::setstatus "ok"
    controller::startcommandloop "AUTH PLAIN \"admin\" \"admin\"\n"
    controller::startstatusloop
    server::newactivitycommand "starting" "started" covers::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
