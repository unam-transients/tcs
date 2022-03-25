########################################################################

# This file is part of the UNAM telescope control system.

# $Id: mountntm.tcl 3601 2020-06-11 03:20:53Z Alan $

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


package require "astrometry"
package require "config"
package require "controller"
package require "client"
package require "log"
package require "pointing"
package require "server"

package provide "mountopentsi" 0.0

config::setdefaultvalue "mount" "controllerhost"             "opentsi"
config::setdefaultvalue "mount" "controllerport"             65432
config::setdefaultvalue "mount" "initialcommand"             "AUTH PLAIN \"admin\" \"admin\"\n"

source [file join [directories::prefix] "lib" "tcs" "mount.tcl"]

config::setdefaultvalue "mount" "allowedpositionerror"       "4as"
config::setdefaultvalue "mount" "pointingmodelparameters0"   [dict create]
config::setdefaultvalue "mount" "pointingmodelpolarhole"     "0"
config::setdefaultvalue "mount" "pointingmodelID0"           "0"
config::setdefaultvalue "mount" "pointingmodelIH0"           "0"
config::setdefaultvalue "mount" "pointingmodelparameters180" [dict create]
config::setdefaultvalue "mount" "pointingmodelID180"         "0"
config::setdefaultvalue "mount" "pointingmodelIH180"         "0"
config::setdefaultvalue "mount" "allowedguideoffset"         "30as"
config::setdefaultvalue "mount" "trackingsettledlimit"       "1as"
config::setdefaultvalue "mount" "axisdhacorrection"          "0"
config::setdefaultvalue "mount" "axisddeltacorrection"       "0"
config::setdefaultvalue "mount" "easthalimit"                "-12h"
config::setdefaultvalue "mount" "westhalimit"                "+12h"
config::setdefaultvalue "mount" "westhalimit"                "+12h"
config::setdefaultvalue "mount" "meridianhalimit"            "0"
config::setdefaultvalue "mount" "northdeltalimit"            "+90d"
config::setdefaultvalue "mount" "southdeltalimit"            "-90d"
config::setdefaultvalue "mount" "polardeltalimit"            "0"
config::setdefaultvalue "mount" "zenithdistancelimit"        "90d"
config::setdefaultvalue "mount" "hapark"                     "0h"
config::setdefaultvalue "mount" "deltapark"                  "90h"
config::setdefaultvalue "mount" "haunpark"                   "0h"
config::setdefaultvalue "mount" "deltaunpark"                "0d"

namespace eval "mount" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost              [config::getvalue "mount" "controllerhost"]
  variable controllerport              [config::getvalue "mount" "controllerport"]
  variable initialcommand              [config::getvalue "mount" "initialcommand"] 
  
  variable allowedpositionerror        [astrometry::parseangle [config::getvalue "mount" "allowedpositionerror"]]
  variable pointingmodelpolarhole      [astrometry::parsedistance [config::getvalue "mount" "pointingmodelpolarhole"]]
  variable allowedguideoffset          [astrometry::parseoffset [config::getvalue "mount" "allowedguideoffset"]]
  variable axisdhacorrection           [astrometry::parseoffset [config::getvalue "mount" "axisdhacorrection"]]
  variable axisddeltacorrection        [astrometry::parseoffset [config::getvalue "mount" "axisddeltacorrection"]]
  variable trackingsettledlimit        [astrometry::parseoffset [config::getvalue "mount" "trackingsettledlimit"]]
  variable easthalimit                 [astrometry::parseha    [config::getvalue "mount" "easthalimit"]]
  variable westhalimit                 [astrometry::parseha    [config::getvalue "mount" "westhalimit"]]
  variable meridianhalimit             [astrometry::parseha    [config::getvalue "mount" "meridianhalimit"]]
  variable northdeltalimit             [astrometry::parsedelta [config::getvalue "mount" "northdeltalimit"]]
  variable southdeltalimit             [astrometry::parsedelta [config::getvalue "mount" "southdeltalimit"]]
  variable polardeltalimit             [astrometry::parsedelta [config::getvalue "mount" "polardeltalimit"]]
  variable zenithdistancelimit         [astrometry::parseangle [config::getvalue "mount" "zenithdistancelimit"]]
  variable hapark                      [astrometry::parseangle [config::getvalue "mount" "hapark"]]
  variable deltapark                   [astrometry::parseangle [config::getvalue "mount" "deltapark"]]
  variable haunpark                    [astrometry::parseangle [config::getvalue "mount" "haunpark"]]
  variable deltaunpark                 [astrometry::parseangle [config::getvalue "mount" "deltaunpark"]]

  ######################################################################

  variable pointingmodelparameters0   [config::getvalue "mount" "pointingmodelparameters0"]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "ID" [config::getvalue "mount" "pointingmodelID0"]]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "IH" [config::getvalue "mount" "pointingmodelIH0"]]

  variable pointingmodelparameters180 [config::getvalue "mount" "pointingmodelparameters180"]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "ID" [config::getvalue "mount" "pointingmodelID180"]]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "IH" [config::getvalue "mount" "pointingmodelIH180"]]

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
    POSITION.HORIZONTAL.AZ
    POSITION.HORIZONTAL.ZD
    POSITION.EQUATORIAL.RA_J2000
    POSITION.EQUATORIAL.DEC_J2000
  } ";"]\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::updatedata                  mount::updatecontrollerdata
  set controller::statusintervalmilliseconds  200

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "mounttracking"              "unknown"
  server::setdata "mountha"                     ""
  server::setdata "mountalpha"                  ""
  server::setdata "mountdelta"                  ""
  server::setdata "axismeanhatrackingerror"     ""
  server::setdata "axismeandeltatrackingerror"  ""
  server::setdata "mountmeaneasttrackingerror"  ""
  server::setdata "mountmeannorthtrackingerror" ""
  server::setdata "mountrmseasttrackingerror"   ""
  server::setdata "mountrmsnorthtrackingerror"  ""
  server::setdata "mountpveasttrackingerror"    ""
  server::setdata "mountpvnorthtrackingerror"   ""
  server::setdata "mountazimuth"                ""
  server::setdata "mountzenithdistance"         ""
  server::setdata "mountrotation"               ""
  server::setdata "state"                       ""
  server::setdata "timestamp"                   ""
  server::setdata "lastcorrectiontimestamp"     ""
  server::setdata "lastcorrectiondalpha"        ""
  server::setdata "lastcorrectionddelta"        ""
  
  server::setdata "requestedobservedalpha"     ""
  server::setdata "requestedobserveddelta"     ""
  server::setdata "requestedobservedha"        ""
  server::setdata "requestedobservedalpharate" ""
  server::setdata "requestedobserveddeltarate" ""
  server::setdata "requestedmountrotation"     ""

  server::setdata "requestedmountalpha"        ""
  server::setdata "requestedmountdelta"        ""
  server::setdata "requestedmountha"           ""
  server::setdata "requestedmountalpharate"    ""
  server::setdata "requestedmountdeltarate"    ""

  server::setdata "mountalphaerror"            ""
  server::setdata "mountdeltaerror"            ""
  server::setdata "mounthaerror"               ""

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [regexp {TPL2 .*} $controllerresponse] == 1 ||
      [regexp {AUTH OK .*} $controllerresponse] == 1 ||
      [regexp {^[0-9]+ COMMAND OK}  $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $controllerresponse] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $controllerresponse] == 1
    }
  }

  variable pendingmountazimuth
  variable pendingmountzenithdistance
  variable pendingmountalpha
  variable pendingmountdelta

  proc updatecontrollerdata {controllerresponse} {

    variable pendingmountazimuth
    variable pendingmountzenithdistance
    variable pendingmountalpha
    variable pendingmountdelta

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]
    
    log::debug "controller response: \"$controllerresponse\"."

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

    if {[scan $controllerresponse "%*d DATA INLINE POSITION.HORIZONTAL.AZ=%f" value] == 1} {
      set pendingmountazimuth [astrometry::degtorad $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.HORIZONTAL.ZD=%f" value] == 1} {
      set pendingmountzenithdistance [astrometry::degtorad $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.EQUATORIAL.RA_J2000=%f" value] == 1} {
      set pendingmountalpha [astrometry::hrtorad $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.EQUATORIAL.DEC_J2000=%f" value] == 1} {
      set pendingmountdelta [astrometry::degtorad $value]
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
    
    set mountazimuth        $pendingmountazimuth
    set mountzenithdistance $pendingmountzenithdistance
    set mountalpha          $pendingmountalpha
    set mountdelta          $pendingmountdelta

    set timestamp [utcclock::combinedformat "now"]

    server::setdata "timestamp"           $timestamp
    server::setdata "mountazimuth"        $mountazimuth
    server::setdata "mountzenithdistance" $mountzenithdistance
    server::setdata "mountalpha"          $mountalpha
    server::setdata "mountdelta"          $mountdelta

    updaterequestedpositiondata false

    server::setstatus "ok"

    return true
  }

  ######################################################################

  variable emergencystopped false

  proc startemergencystop {} {
    log::error "starting emergency stop."
    log::warning "stopping the mount."
    log::debug "emergency stop: sending emergency stop."
    variable emergencystopcommandidentifier
    set command "$emergencystopcommandidentifier SET HA.STOP=1;DEC.STOP=1"
    log::debug "emergency stop: sending command \"$command\"."
    controller::flushcommandqueue
    controller::pushcommand "$command\n"
    log::debug "emergency stop: finished sending emergency stop."
    server::setdata "mounttracking" false
    variable emergencystopped
    set emergencystopped true
    server::erroractivity
  }

  proc finishemergencystop {} {
    log::error "finished emergency stop."
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

  proc sendcommandandwait {command} {
    variable currentcommandidentifier
    variable completedcurrentcommand
    set start [utcclock::seconds]
    set completedcurrentcommand false
    sendcommand $command    
    coroutine::yield
    while {!$completedcurrentcommand} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::debug [format "completed controller command $currentcommandidentifier after %.1f seconds." [utcclock::diff $end $start]]
  }

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
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    initializeactivitycommand
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc rebootactivitycommand {} {
    set start [utcclock::seconds]
    log::info "rebooting."
    set end [utcclock::seconds]
    log::info [format "finished rebooting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
  }

  proc checktarget {activity expectedactivity} {
  }

  proc moveactivitycommand {} {
    set start [utcclock::seconds]
    log::info "moving."
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "parking."
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc unparkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "unparking."
    set end [utcclock::seconds]
    log::info [format "finished unparking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
  }

  proc trackoroffsetactivitycommand {move} {
    set start [utcclock::seconds]
    if {$move} {
      log::info "moving to track."
    }
    log::info [format "started tracking after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "tracking"
    server::clearactivitytimeout
  }
  
  proc trackactivitycommand {} {
    trackoroffsetactivitycommand true
  }

  proc offsetactivitycommand {} {
    updaterequestedpositiondata true
    trackoroffsetactivitycommand false
  }

  ######################################################################

}
