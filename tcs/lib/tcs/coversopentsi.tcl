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
config::setdefaultvalue "covers" "controllerhost" "opentsi"

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
  server::setdata "readystate"       ""
  server::setdata "referencestate"   ""
  server::setdata "errorstate"       ""

  variable settledelayseconds 5

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

  variable readystate
  variable covers
  variable port2cover
  variable port3cover

  proc updatecontrollerdata {controllerresponse} {

    variable readystate
    variable covers
    variable port2cover
    variable port3cover

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

    if {[scan $controllerresponse "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      set readystate $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.COVER.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set covers "closed"
      } elseif {$value == 1.0} {
        set covers "open"
      } else {
        set covers "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.PORT_COVER\[2\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set port2cover "closed"
      } elseif {$value == 1.0} {
        set port2cover "open"
      } else {
        set port2cover "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE AUXILIARY.PORT_COVER\[3\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set port3cover "closed"
      } elseif {$value == 1.0} {
        set port3cover "open"
      } else {
        set port3cover "intermediate"
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

    set timestamp [utcclock::combinedformat "now"]

    set lasttimestamp      [server::getdata "timestamp"]
    set lastreadystate     [server::getdata "readystate"]
    set lastcovers         [server::getdata "covers"]
    set lastport2cover     [server::getdata "port2cover"]
    set lastport3cover     [server::getdata "port3cover"]
    set stoppedtimestamp   [server::getdata "stoppedtimestamp"]
    
    if {![string equal $lastreadystate ""] && ![string equal $readystate $lastreadystate]} {
      log::info "ready state changed from $lastreadystate to $readystate."
    }
    if {![string equal $lastcovers ""] && ![string equal $covers $lastcovers]} {
      log::info "covers changed from \"$lastcovers\" to \"$covers\"."
    }
    if {![string equal $lastport2cover ""] && ![string equal $port2cover $lastport2cover]} {
      log::info "port 2 cover changed from \"$lastport2cover\" to \"$port2cover\"."
    }
    if {![string equal $lastport3cover ""] && ![string equal $port3cover $lastport3cover]} {
      log::info "port 3 covers changed from \"$lastport3cover\" to \"$port3cover\"."
    }

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
    
    server::setdata "timestamp"        $timestamp
    server::setdata "readystate"       $readystate
    server::setdata "covers"           $covers
    server::setdata "port2cover"       $port2cover
    server::setdata "port3cover"       $port3cover
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled

    server::setstatus "ok"

    return true
  }

  ######################################################################
  
  variable currentcommandidentifier 0
  variable nextcommandidentifier $firstnormalcommandidentifier
  variable completedcurrentcommand

  proc sendcommand {command} {
    variable currentcommandidentifier
    variable nextcommandidentifier
    variable completedcurrentcommand
    variable firstnormalcommandidentifier
    variable lastnormalcommandidentifier
    set currentcommandidentifier $nextcommandidentifier
    if {$nextcommandidentifier == $lastnormalcommandidentifier} {
      set nextcommandidentifier $firstnormalcommandidentifier
    } else {
      set nextcommandidentifier [expr {$nextcommandidentifier + 1}]
    }
    log::debug "sending controller command $currentcommandidentifier: \"$command\"."
    controller::pushcommand "$currentcommandidentifier $command\n"
  }

  proc stopcovers {} {
    server::setdata "requestedcovers" ""
    variable readystate
    if {$readystate != 1.0} {
      log::error "unable to stop: telescope ready state is $readystate."
    } else {
      log::info "stopping."
      sendcommand "SET TELESCOPE.STOP=1"
    }
  }
  
  proc opencovers {} {
    server::setdata "requestedcovers" "open"
    variable readystate
    if {$readystate != 1.0} {
      log::error "unable to open: telescope ready state is $readystate."
    } else {
      sendcommand "SET AUXILIARY.COVER.TARGETPOS=1"
      sendcommand "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=1"
      sendcommand "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=1"
      settle
      if {![string equal [server::getdata "covers"] "open"]} {
        error "the covers did not open."
      }
    }
  }
  
  proc closecovers {} {
    server::setdata "requestedcovers" "closed"
    variable readystate
    if {$readystate != 1.0} {
      log::error "unable to close: telescope ready state is $readystate."
    } else {
      sendcommand "SET AUXILIARY.COVER.TARGETPOS=0"
      sendcommand "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=0"
      sendcommand "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=0"
      settle
      if {![string equal [server::getdata "covers"] "closed"]} {
        error "the covers did not close."
      }
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
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    variable readystate
    if {$readystate != 1.0} {
      log::info "powering up telescope."
      sendcommand "SET TELESCOPE.POWER=1"
      log::info "waiting for telescope to power up."
      while {$readystate != 1.0} {
        coroutine::yield
      }
    }
    log::info "closing."
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

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    if {
      [string equal $previousactivity "initializing"] || 
      [string equal $previousactivity "opening"] || 
      [string equal $previousactivity "closing"]
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