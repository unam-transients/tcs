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
    TELESCOPE.READY_STATE
    TELESCOPE.MOTION_STATE
    POSITION.HORIZONTAL.AZ
    POSITION.HORIZONTAL.ZD
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

  variable fakecontrollererror false

  variable hamotionstate    ""
  variable deltamotionstate ""

  variable haaxismoving        true
  variable deltaaxismoving     true
  variable haaxistrajectory    false
  variable deltaaxistrajectory false
  variable haaxisblocked       false
  variable deltaaxisblocked    false
  variable haaxisacquired      false
  variable deltaaxisacquired   false
  variable haaxislimited       false
  variable deltaaxislimited    false
  variable haaxistracking      false
  variable deltaaxistracking   false
  variable moving              true
  variable waitmoving          true
  variable tracking            false
  variable forcenottracking    true
  variable waittracking        false
  variable trackingtimestamp   ""
  variable settling            false
  variable settlingtimestamp   ""
  variable cabinetstatuslist   ""
  variable cabinetpowerstate   ""
  variable cabineterrorstate   ""
  variable cabinetreferenced   ""
  variable haaxisreferenced    ""
  variable deltaaxisreferenced ""
  variable gpsreferenced       ""
  variable state               ""
  variable freepoints          0

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [regexp {TPL2 .*} $controllerresponse] == 1 ||
      [string equal {AUTH OK .*} $controllerresponse] ||
      [regexp {^[0-9]+ COMMAND OK}  $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $controllerresponse] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $controllerresponse] == 1
    }
  }

  variable pendingreadystate
  variable pendingmotionstate
  variable pendingmountazimuth
  variable pendingmountzenithdistance

  proc updatecontrollerdata {controllerresponse} {

    variable pendingreadystate
    variable pendingmotionstate
    variable pendingmountazimuth
    variable pendingmountzenithdistance

    variable fakecontrollererror
    if {$fakecontrollererror} {
      set fakecontrollererror false
      set controllerresponse "FAKE CONTROLLER ERROR"
    }

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]
    
    log::info "controller response: \"$controllerresponse\"."

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
      set pendingreadystate $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE TELESCOPE.MOTION_STATE=%d" value] == 1} {
      set pendingmotionstate $value
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
    if {[regexp {[0-9]+ DATA INLINE } $controllerresponse] == 1} {
      log::debug "status: ignoring DATA INLINE response."
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $controllerresponse] != 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }
    
    set readystate          $pendingreadystate
    set motionstate         $pendingmotionstate
    set mountazimuth        $pendingmountazimuth
    set mountzenithdistance $pendingmountzenithdistance

    set timestamp [utcclock::combinedformat "now"]

    server::setdata "timestamp"           $timestamp
    server::setdata "readystate"          $readystate
    server::setdata "motionstate"         $motionstate
    server::setdata "mountazimuth"        $mountazimuth
    server::setdata "mountzenithdistance" $mountzenithdistance

    server::setstatus "ok"

    return true
  }

  proc updaterequestedpositiondata {{updaterequestedrotation false}} {

    log::debug "updating requested position."

    set seconds [utcclock::seconds]

    if {[catch {client::update "target"} message]} {
      error "unable to update target data: $message"
    }
    set targetstatus   [client::getstatus "target"]
    set targetactivity [client::getdata "target" "activity"]
    log::debug "target status is \"$targetstatus\"."
    log::debug "target activity is \"$targetactivity\"."

    set activity [server::getactivity]
    set requestedactivity [server::getrequestedactivity]
    log::debug "continuing to update requested position for activity \"$activity\" and requested activity \"$requestedactivity\"."

    set mountha       [server::getdata "mountha"      ]
    set mountalpha    [server::getdata "mountalpha"   ]
    set mountdelta    [server::getdata "mountdelta"   ]
    set mountrotation [server::getdata "mountrotation"]

    if {
      [string equal $requestedactivity "tracking"] &&
      [string equal $targetstatus "ok"] &&
      [string equal $targetactivity "tracking"]
    } {

      log::debug "updating requested position in the tracking/ok/tracking branch."

      set requestedtimestamp         [client::getdata "target" "timestamp"]

      set requestedobservedha        [client::getdata "target" "observedha"]
      set requestedobservedalpha     [client::getdata "target" "observedalpha"]
      set requestedobserveddelta     [client::getdata "target" "observeddelta"]
      set requestedobservedharate    [client::getdata "target" "observedharate"]
      set requestedobservedalpharate [client::getdata "target" "observedalpharate"]
      set requestedobserveddeltarate [client::getdata "target" "observeddeltarate"]
      
      if {$updaterequestedrotation} {
        set requestedmountrotation [mountrotation $requestedobservedha $requestedobservedalpha]
      } else {
        set requestedmountrotation $mountrotation
      }

      set seconds [utcclock::scan $requestedtimestamp]
      set dseconds 60
      set futureseconds [expr {$seconds + $dseconds}]

      set mountdha    [mountdha    $requestedobservedha    $requestedobserveddelta $requestedmountrotation]
      set mountdalpha [mountdalpha $requestedobservedalpha $requestedobserveddelta $requestedmountrotation $seconds]
      set mountddelta [mountddelta $requestedobservedalpha $requestedobserveddelta $requestedmountrotation $seconds]

      set requestedmountha    [astrometry::foldradsymmetric [expr {$requestedobservedha + $mountdha}]]
      set requestedmountalpha [astrometry::foldradpositive [expr {$requestedobservedalpha + $mountdalpha}]]
      set requestedmountdelta [expr {$requestedobserveddelta + $mountddelta}]

      set futurerequestedmountrotation $requestedmountrotation
      set futurerequestedobservedha    [astrometry::foldradsymmetric [expr {
        $requestedobservedha + $dseconds * $requestedobservedharate
      }]]
      set futurerequestedobservedalpha [astrometry::foldradpositive [expr {
        $requestedobservedalpha + $dseconds * $requestedobservedalpharate / cos($requestedobserveddelta)
      }]]
      set futurerequestedobserveddelta [expr {
        $requestedobserveddelta + $dseconds * $requestedobserveddeltarate
      }]

      set futuremountdha    [mountdha    $futurerequestedobservedha    $futurerequestedobserveddelta $futurerequestedmountrotation]
      set futuremountdalpha [mountdalpha $futurerequestedobservedalpha $futurerequestedobserveddelta $futurerequestedmountrotation $futureseconds]
      set futuremountddelta [mountddelta $futurerequestedobservedalpha $futurerequestedobserveddelta $futurerequestedmountrotation $futureseconds]

      set futurerequestedmountha    [astrometry::foldradsymmetric [expr {$futurerequestedobservedha + $futuremountdha}]]
      set futurerequestedmountalpha [astrometry::foldradpositive [expr {$futurerequestedobservedalpha + $futuremountdalpha}]]
      set futurerequestedmountdelta [expr {$futurerequestedobserveddelta + $futuremountddelta}]

      set requestedmountharate      [astrometry::foldradsymmetric [expr {
        ($futurerequestedmountha - $requestedmountha) / $dseconds
      }]]
      set requestedmountalpharate   [astrometry::foldradsymmetric [expr {
        ($futurerequestedmountalpha - $requestedmountalpha) / $dseconds * cos($requestedobserveddelta)
      }]]
      set requestedmountdeltarate   [expr {
        ($futurerequestedmountdelta - $requestedmountdelta) / $dseconds
      }]

      set mounthaerror    ""
      set mountalphaerror [astrometry::foldradsymmetric [expr {$mountalpha - $requestedmountalpha}]]
      set mountdeltaerror [expr {$mountdelta - $requestedmountdelta}]

    } elseif {
      [string equal $requestedactivity "idle"] &&
      [string equal $targetstatus "ok"] &&
      [string equal $targetactivity "idle"]
    } {

      log::debug "updating requested position in the idle/ok/idle branch."

      set requestedtimestamp         [client::getdata "target" "timestamp"]

      set requestedobservedha        [client::getdata "target" "observedha"]
      set requestedobservedalpha     [client::getdata "target" "observedalpha"]
      set requestedobserveddelta     [client::getdata "target" "observeddelta"]
      set requestedobservedharate    ""
      set requestedobservedalpharate ""
      set requestedobserveddeltarate ""

      if {$updaterequestedrotation} {
        set requestedmountrotation [mountrotation $requestedobservedha $requestedobservedalpha]
      } else {
        set requestedmountrotation $mountrotation
      }
      
      set mountdha    [mountdha    $requestedobservedha    $requestedobserveddelta $requestedmountrotation]
      set mountddelta [mountddelta $requestedobservedalpha $requestedobserveddelta $requestedmountrotation]

      set requestedmountha         [astrometry::foldradsymmetric [expr {$requestedobservedha + $mountdha}]]
      set requestedmountalpha      ""
      set requestedmountdelta      [expr {$requestedobserveddelta + $mountddelta}]

      set requestedmountharate     ""
      set requestedmountalpharate  ""
      set requestedmountdeltarate  ""

      set mounthaerror    [astrometry::foldradsymmetric [expr {$mountha    - $requestedmountha   }]]
      set mountalphaerror ""
      set mountdeltaerror [expr {$mountdelta - $requestedmountdelta}]

    } else {

      log::debug "updating requested position in the last branch."

      set requestedtimestamp         ""

      set requestedmountrotation     ""
      set requestedobservedha        ""
      set requestedobservedalpha     ""
      set requestedobserveddelta     ""
      set requestedobservedharate    ""
      set requestedobservedalpharate ""
      set requestedobserveddeltarate ""

      set requestedmountha        ""
      set requestedmountalpha     ""
      set requestedmountdelta     ""
      set requestedmountharate    ""
      set requestedmountalpharate ""
      set requestedmountdeltarate ""

      set mounthaerror    ""
      set mountalphaerror ""
      set mountdeltaerror ""

    }

    server::setdata "requestedtimestamp"         $requestedtimestamp
    server::setdata "requestedmountrotation"     $requestedmountrotation
    server::setdata "requestedobservedha"        $requestedobservedha
    server::setdata "requestedobservedalpha"     $requestedobservedalpha
    server::setdata "requestedobserveddelta"     $requestedobserveddelta
    server::setdata "requestedobservedharate"    $requestedobservedharate
    server::setdata "requestedobservedalpharate" $requestedobservedalpharate
    server::setdata "requestedobserveddeltarate" $requestedobserveddeltarate
    server::setdata "requestedmountha"           $requestedmountha
    server::setdata "requestedmountalpha"        $requestedmountalpha
    server::setdata "requestedmountdelta"        $requestedmountdelta
    server::setdata "requestedmountharate"       $requestedmountharate
    server::setdata "requestedmountalpharate"    $requestedmountalpharate
    server::setdata "requestedmountdeltarate"    $requestedmountdeltarate
    server::setdata "mounthaerror"               $mounthaerror
    server::setdata "mountalphaerror"            $mountalphaerror
    server::setdata "mountdeltaerror"            $mountdeltaerror

    log::debug "finished updating requested position."
  }
  
  ######################################################################
  
  variable sumaxishatrackingerror       0
  variable sumaxisdeltatrackingerror    0
  variable summounteasttrackingerror    0
  variable summountnorthtrackingerror   0
  variable sumsqmounteasttrackingerror  0
  variable sumsqmountnorthtrackingerror 0
  variable nmounttrackingerror          0

  variable maxmounteasttrackingerror    ""
  variable minmounteasttrackingerror    ""
  variable maxmountnorthtrackingerror   ""
  variable minmountnorthtrackingerror   ""

  variable axismeanhatrackingerror      ""
  variable axismeandeltatrackingerror   ""
  variable mountmeaneasttrackingerror   ""
  variable mountmeannorthtrackingerror  ""
  variable mountrmseasttrackingerror    ""
  variable mountrmsnorthtrackingerror   ""
  variable maxmounteasttrackingerror    ""
  variable minmounteasttrackingerror    ""
  variable maxmountnorthtrackingerror   ""
  variable minmountnorthtrackingerror   ""
  variable mountpveasttrackingerror     ""
  variable mountpvnorthtrackingerror    ""

  proc maybestarttracking {} {
    variable forcenottracking
    set forcenottracking false
  }
  
  proc updatetracking {axishatrackingerror axisdeltatrackingerror mounteasttrackingerror mountnorthtrackingerror} {

    variable sumaxishatrackingerror
    variable sumaxisdeltatrackingerror
    variable summounteasttrackingerror
    variable summountnorthtrackingerror
    variable sumsqmounteasttrackingerror
    variable sumsqmountnorthtrackingerror
    variable nmounttrackingerror

    variable axismeanhatrackingerror
    variable axismeandeltatrackingerror
    variable mountmeaneasttrackingerror
    variable mountmeannorthtrackingerror
    variable mountrmseasttrackingerror
    variable mountrmsnorthtrackingerror
    variable maxmounteasttrackingerror
    variable minmounteasttrackingerror
    variable maxmountnorthtrackingerror
    variable minmountnorthtrackingerror
    variable mountpveasttrackingerror
    variable mountpvnorthtrackingerror

    set sumaxishatrackingerror       [expr {$sumaxishatrackingerror       + $axishatrackingerror}]
    set sumaxisdeltatrackingerror    [expr {$sumaxisdeltatrackingerror    + $axisdeltatrackingerror}]
    set summounteasttrackingerror    [expr {$summounteasttrackingerror    + $mounteasttrackingerror}]
    set summountnorthtrackingerror   [expr {$summountnorthtrackingerror   + $mountnorthtrackingerror}]
    set sumsqmounteasttrackingerror  [expr {$sumsqmounteasttrackingerror  + pow($mounteasttrackingerror , 2)}]
    set sumsqmountnorthtrackingerror [expr {$sumsqmountnorthtrackingerror + pow($mountnorthtrackingerror, 2)}]
    set nmounttrackingerror          [expr {$nmounttrackingerror + 1}]

    set axismeanhatrackingerror      [expr {$sumaxishatrackingerror     / $nmounttrackingerror}]
    set axismeandeltatrackingerror   [expr {$sumaxisdeltatrackingerror  / $nmounttrackingerror}]
    set mountmeaneasttrackingerror   [expr {$summounteasttrackingerror  / $nmounttrackingerror}]
    set mountmeannorthtrackingerror  [expr {$summountnorthtrackingerror / $nmounttrackingerror}]
    set mountrmseasttrackingerror    [expr {sqrt(($sumsqmounteasttrackingerror  - $nmounttrackingerror * pow($mountmeaneasttrackingerror , 2)) / $nmounttrackingerror)}]
    set mountrmsnorthtrackingerror   [expr {sqrt(($sumsqmountnorthtrackingerror - $nmounttrackingerror * pow($mountmeannorthtrackingerror, 2)) / $nmounttrackingerror)}]
    if {[string equal $maxmounteasttrackingerror ""]} {
      set maxmounteasttrackingerror  $mounteasttrackingerror
    } else {
      set maxmounteasttrackingerror  [expr {max($maxmounteasttrackingerror,$mounteasttrackingerror)}]
    }
    if {[string equal $minmounteasttrackingerror ""]} {
      set minmounteasttrackingerror  $mounteasttrackingerror
    } else {
      set minmounteasttrackingerror  [expr {min($minmounteasttrackingerror,$mounteasttrackingerror)}]
    }
    if {[string equal $maxmountnorthtrackingerror ""]} {
      set maxmountnorthtrackingerror $mountnorthtrackingerror
    } else {
      set maxmountnorthtrackingerror [expr {max($maxmountnorthtrackingerror,$mountnorthtrackingerror)}]
    }
    if {[string equal $minmountnorthtrackingerror ""]} {
      set minmountnorthtrackingerror $mountnorthtrackingerror
    } else {
      set minmountnorthtrackingerror [expr {min($minmountnorthtrackingerror,$mountnorthtrackingerror)}]
    }
    set mountpveasttrackingerror     [expr {$maxmounteasttrackingerror-$minmounteasttrackingerror}]
    set mountpvnorthtrackingerror    [expr {$maxmountnorthtrackingerror-$minmountnorthtrackingerror}]

    server::setdata "axismeanhatrackingerror"     $axismeanhatrackingerror
    server::setdata "axismeandeltatrackingerror"  $axismeandeltatrackingerror
    server::setdata "mountmeaneasttrackingerror"  $mountmeaneasttrackingerror
    server::setdata "mountmeannorthtrackingerror" $mountmeannorthtrackingerror
    server::setdata "mountrmseasttrackingerror"   $mountrmseasttrackingerror
    server::setdata "mountrmsnorthtrackingerror"  $mountrmsnorthtrackingerror
    server::setdata "mountpveasttrackingerror"    $mountpveasttrackingerror
    server::setdata "mountpvnorthtrackingerror"   $mountpvnorthtrackingerror

  }
  
  proc maybeendtracking {} {

    variable tracking
    variable lasttracking
    variable trackingtimestamp

    variable sumaxishatrackingerror
    variable sumaxisdeltatrackingerror
    variable summounteasttrackingerror
    variable summountnorthtrackingerror
    variable sumsqmounteasttrackingerror
    variable sumsqmountnorthtrackingerror
    variable nmounttrackingerror

    variable axismeanhatrackingerror
    variable axismeandeltatrackingerror
    variable mountmeaneasttrackingerror
    variable mountmeannorthtrackingerror
    variable mountrmseasttrackingerror
    variable mountrmsnorthtrackingerror
    variable maxmounteasttrackingerror
    variable minmounteasttrackingerror
    variable maxmountnorthtrackingerror
    variable minmountnorthtrackingerror
    variable mountpveasttrackingerror
    variable mountpvnorthtrackingerror

    if {$tracking} {
      log::info [format "stopped tracking after %.1f seconds." [utcclock::diff now $trackingtimestamp]]
      if {
        ![string equal $axismeanhatrackingerror ""] &&
        ![string equal $axismeandeltatrackingerror ""]
      } {
        log::info [format \
          "mean axis tracking errors were %+.2fas in HA and %+.2fas in δ." \
          [astrometry::radtoarcsec $axismeanhatrackingerror] \
          [astrometry::radtoarcsec $axismeandeltatrackingerror] \
        ]
      }
      if {
        ![string equal $mountmeaneasttrackingerror ""] &&
        ![string equal $mountmeannorthtrackingerror ""]
      } {
        log::info [format \
          "mean tracking errors were %+.2fas east and %+.2fas north." \
          [astrometry::radtoarcsec $mountmeaneasttrackingerror] \
          [astrometry::radtoarcsec $mountmeannorthtrackingerror] \
        ]
      }
      if {
        ![string equal $mountrmseasttrackingerror ""] &&
        ![string equal $mountrmsnorthtrackingerror ""]
      } {
        log::info [format \
          "RMS tracking errors were %.2fas east and %.2fas north." \
          [astrometry::radtoarcsec $mountrmseasttrackingerror] \
          [astrometry::radtoarcsec $mountrmsnorthtrackingerror] \
        ]
      }
      if {
        ![string equal $mountpveasttrackingerror ""] &&
        ![string equal $mountpvnorthtrackingerror ""]
      } {
        log::info [format \
          "P-V tracking errors were %.2fas east and %.2fas north." \
          [astrometry::radtoarcsec $mountpveasttrackingerror] \
          [astrometry::radtoarcsec $mountpvnorthtrackingerror] \
        ]
      }
    }

    set tracking                     false
    set trackingtimestamp            ""

    set sumaxishatrackingerror       0
    set sumaxisdeltatrackingerror    0
    set summounteasttrackingerror    0
    set summountnorthtrackingerror   0
    set sumsqmounteasttrackingerror  0
    set sumsqmountnorthtrackingerror 0
    set nmounttrackingerror          0

    set axismeanhatrackingerror      ""
    set axismeandeltatrackingerror   ""
    set mountmeaneasttrackingerror   ""
    set mountmeannorthtrackingerror  ""
    set mountrmseasttrackingerror    ""
    set mountrmsnorthtrackingerror   ""
    set maxmounteasttrackingerror    ""
    set minmounteasttrackingerror    ""
    set maxmountnorthtrackingerror   ""
    set minmountnorthtrackingerror   ""
    set mountpveasttrackingerror     ""
    set mountpvnorthtrackingerror    ""

    server::setdata "axismeanhatrackingerror"     $axismeanhatrackingerror
    server::setdata "axismeandeltatrackingerror"  $axismeandeltatrackingerror
    server::setdata "mountmeaneasttrackingerror"  $mountmeaneasttrackingerror
    server::setdata "mountmeannorthtrackingerror" $mountmeannorthtrackingerror
    server::setdata "mountrmseasttrackingerror"   $mountrmseasttrackingerror
    server::setdata "mountrmsnorthtrackingerror"  $mountrmsnorthtrackingerror
    server::setdata "mountpveasttrackingerror"    $mountpveasttrackingerror
    server::setdata "mountpvnorthtrackingerror"   $mountpvnorthtrackingerror

    variable forcenottracking
    set forcenottracking true
  }
  
  ######################################################################

  proc withinlimits {mountha mountdelta mountrotation} {

    variable easthalimit
    variable westhalimit
    variable meridianhalimit
    variable polardeltalimit
    variable southdeltalimit
    variable northdeltalimit
    variable zenithdistancelimit

    set mountzenithdistance [astrometry::zenithdistance $mountha $mountdelta]
    
    if {$mountha < $easthalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds eastern limit."
      return false
    } elseif {$mountha > $westhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds western limit."
      return false
    } elseif {$mountdelta < $southdeltalimit} {
      log::warning "δ exceeds southern limit."
      return false
    } elseif {$mountdelta > $northdeltalimit} {
      log::warning "δ exceeds northern limit."
      return false
    } elseif {$mountzenithdistance > $zenithdistancelimit} {
      log::warning "zenith distance exceeds limit."
      return false
    } elseif {$mountrotation == 0 && $mountha <= -$meridianhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds eastern meridian limit."
      return false
    } elseif {$mountrotation != 0 && $mountha >= +$meridianhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds western meridian limit."
      return false
    } else {
      return true
    }

  }

  ######################################################################

  proc axisha {ha delta mountrotation} {
    if {$mountrotation == 0} {
      return $ha
    } else {
      return [expr {[astrometry::pi] + $ha}]
    }
  }

  proc axisdelta {ha delta mountrotation} {
    if {$mountrotation == 0} {
      return $delta
    } else {
      return [expr {[astrometry::pi] - $delta}]
    }
  }

  proc mountrotation {ha delta} {
    if {$ha >= 0} {
      return 0
    } else {
      return [astrometry::pi]
    }
  }

  ######################################################################

  proc pointingmodelparameters {rotation} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      return $pointingmodelparameters0
    } else {
      return $pointingmodelparameters180
    }
  }

  proc setpointingmodelparameters {rotation newpointingmodelparameters} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      set pointingmodelparameters0 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID0" [pointing::getparameter $pointingmodelparameters0 "ID"]
      config::setvarvalue "mount" "pointingmodelIH0" [pointing::getparameter $pointingmodelparameters0 "IH"]
    } else {
      set pointingmodelparameters180 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID180" [pointing::getparameter $pointingmodelparameters180 "ID"]
      config::setvarvalue "mount" "pointingmodelIH180" [pointing::getparameter $pointingmodelparameters180 "IH"]
    }
  }

  proc mountdha {ha delta rotation} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dha 0
    } else {
      set dha [pointing::modeldha [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dha
  }

  proc mountdalpha {alpha delta rotation {seconds "now"}} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dalpha 0
    } else {
      set ha [astrometry::ha $alpha $seconds]
      set dalpha [pointing::modeldalpha  [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dalpha
  }

  proc mountddelta {alpha delta rotation {seconds "now"}} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set ddelta 0
    } else {
      set ha [astrometry::ha $alpha $seconds]
      set ddelta [pointing::modelddelta [pointingmodelparameters $rotation] $ha $delta]
    }
    return $ddelta
  }

  proc updatepointingmodel {dIH dID rotation} {
    setpointingmodelparameters $rotation [pointing::updateabsolutemodel [pointingmodelparameters $rotation] $dIH $dID]
  }
  
  proc setMAtozero {} {
    log::info "setting MA to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   MA 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 MA 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  proc setMEtozero {} {
    log::info "setting ME to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   ME 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 ME 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  ######################################################################

  proc acceptablehaerror {} {
    variable allowedpositionerror
    set haerror [server::getdata "mounthaerror"]
    return [expr {abs($haerror) <= $allowedpositionerror}]
  }

  proc acceptablealphaerror {} {
    variable allowedpositionerror
    set alphaerror [server::getdata "mountalphaerror"]
    return [expr {abs($alphaerror) <= $allowedpositionerror}]
  }

  proc acceptabledeltaerror {} {
    variable allowedpositionerror
    set deltaerror [server::getdata "mountdeltaerror"]
    return [expr {abs($deltaerror) <= $allowedpositionerror}]
  }

  proc checkhaerror {when} {
    variable allowedpositionerror
    set haerror [server::getdata "mounthaerror"]
    if {abs($haerror) > $allowedpositionerror} {
      log::warning "mount HA error is [astrometry::radtohms $haerror 2 true] $when."
    }
  }

  proc checkalphaerror {when} {
    variable allowedpositionerror
    set alphaerror [server::getdata "mountalphaerror"]
    if {abs($alphaerror) > $allowedpositionerror} {
      log::warning "mount alpha error is [astrometry::radtohms $alphaerror 2 true] $when."
    }
  }

  proc checkdeltaerror {when} {
    variable allowedpositionerror
    set deltaerror [server::getdata "mountdeltaerror"]
    if {abs($deltaerror) > $allowedpositionerror} {
      log::warning "mount delta error is [astrometry::radtodms $deltaerror 1 true] $when."
    }
  }

  ######################################################################

  proc offsetcommand {which alphaoffset deltaoffset} {
    set mountdelta [server::getdata "mountdelta"]
    set alphaoffset [expr {$alphaoffset / cos($mountdelta)}]
    set alphaoffset [astrometry::radtoarcsec $alphaoffset]
    set deltaoffset [astrometry::radtoarcsec $deltaoffset]
    while {abs($alphaoffset) > 60 || abs($deltaoffset) > 60} {
      if {$alphaoffset > 60} {
        set dalphaoffset +60
        set alphaoffset [expr {$alphaoffset - 60}]
      } elseif {$alphaoffset < -60} {
        set dalphaoffset -60
        set alphaoffset [expr {$alphaoffset + 60}]
      } else {
        set dalphaoffset 0
      }
      if {$deltaoffset > 60} {
        set ddeltaoffset +60
        set deltaoffset [expr {$deltaoffset - 60}]
      } elseif {$deltaoffset < -60} {
        set ddeltaoffset -60
        set deltaoffset [expr {$deltaoffset + 60}]
      } else {
        set ddeltaoffset 0
      }
      controller::${which}command [format "OFF %+.2f %+.2f\n" $dalphaoffset $ddeltaoffset]
    }
    controller::${which}command [format "OFF %+.2f %+.2f\n" $alphaoffset $deltaoffset]
  }

  ######################################################################

  variable offsetalphalimit [astrometry::parseangle "30as"]
  variable offsetdeltalimit [astrometry::parseangle "30as"]

  proc shouldoffsettotrack {} {
    set mountalphaerror [server::getdata "mountalphaerror"]
    set mountdeltaerror [server::getdata "mountdeltaerror"]
    set mountdelta           [server::getdata "mountdelta"]
    set alphaoffset [expr {$mountalphaerror * cos($mountdelta)}]
    set deltaoffset $mountdeltaerror
    variable offsetalphalimit
    variable offsetdeltalimit
    return [expr {
      [server::getdata "mounttracking"] &&
      abs($alphaoffset) < $offsetalphalimit &&
      abs($deltaoffset) < $offsetdeltalimit
    }]
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

  proc waitwhilemoving {} {
    log::debug "waitwhilemoving: starting."
    variable waitmoving
    set waitmoving false
    while {$waitmoving} {
      log::debug "waitwhilemoving: yielding."
      coroutine::yield
    }
    log::debug "waitwhilemoving: finished."
  }

  proc waitwhilemountrotation {mountrotation} {
    log::debug "waitwhilemountrotation: starting."
    while {$mountrotation == [server::getdata "mountrotation"]} {
      log::debug "waitwhilemountrotation: yielding."
      coroutine::yield
    }
    log::debug "waitwhilemountrotation: finished."
  }
  
  proc waituntilsafetomovebothaxes {} {
    log::debug "waituntilsafetomovebothaxes: starting."
    variable zenithdistancelimit
    while {true} {
      set requestedmountha       [server::getdata "requestedmountha"]
      set requestedmountdelta    [server::getdata "requestedmountdelta"]
      set mountha                [server::getdata "mountha"]
      set mountdelta             [server::getdata "mountdelta"]
      if {
        [astrometry::zenithdistance $requestedmountha $requestedmountdelta] > $zenithdistancelimit
      } {
        error "the requested position is below the zenith distance limit."
      } elseif {
        [astrometry::zenithdistance $mountha $requestedmountdelta] < $zenithdistancelimit &&
        [astrometry::zenithdistance $requestedmountha $mountdelta] < $zenithdistancelimit
      } {
        log::debug "waituntilsafetomovebothaxes: finished."
        return
      }
      log::debug "waituntilsafetomovebothaxes: yielding."
      coroutine::yield
    }
  }

  proc waituntiltracking {} {
    log::debug "waituntiltracking: starting."
    variable waittracking
    set waittracking false
    while {!$waittracking} {
      log::debug "waituntiltracking: yielding."
      coroutine::yield
    }
    log::debug "waituntiltracking: finished."
  }

  proc waituntilnottracking {} {
    log::debug "waituntilnottracking: starting."
    variable tracking
    while {$tracking} {
      log::debug "waituntilnottracking: yielding."
      coroutine::yield
    }
    log::debug "waituntilnottracking: finished."
  }

  proc isoperational {} {
    variable state
    if {[string equal $state "operational"]} {
      return true
    } else {
      return false
    }
  }

  proc waituntiloperational {} {
    log::debug "waituntiloperational: starting."
    while {![isoperational]} {
      log::debug "waituntiloperational: yielding."
      coroutine::yield
    }
    log::debug "waituntiloperational: finished."
  }

  ######################################################################

  proc stophardware {} {
    log::info "stopping the mount."
    controller::flushcommandqueue
    sendcommandandwait "SET HA.STOP=1;DEC.STOP=1"
    waitwhilemoving
  }

  proc movehardware {movetotrack} {

    updaterequestedpositiondata true
    set requestedmountha       [server::getdata "requestedmountha"]
    set requestedmountdelta    [server::getdata "requestedmountdelta"]
    set requestedmountrotation [server::getdata "requestedmountrotation"]

    set mountha                [server::getdata "mountha"]
    set mountdelta             [server::getdata "mountdelta"]
    set mountrotation          [server::getdata "mountrotation"]

    log::info [format \
      "moving from %s %s (%.0f°) to %s %s (%.0f°)." \
      [astrometry::formatha $mountha] \
      [astrometry::formatdelta $mountdelta] \
      [astrometry::radtodeg $mountrotation] \
      [astrometry::formatha $requestedmountha] \
      [astrometry::formatdelta $requestedmountdelta] \
      [astrometry::radtodeg $requestedmountrotation] \
    ]
    server::setdata "mounttracking" false

    if {$mountrotation != $requestedmountrotation} {
      log::info "moving in δ to flip the mount rotation."
      if {$mountrotation == 0} {
        sendcommandandwait "SET DEC.TARGETPOS=100"
      } else {
        sendcommandandwait "SET DEC.TARGETPOS=80"
      }
      waitwhilemountrotation $mountrotation
      set mountha       [server::getdata "mountha"]
      set mountdelta    [server::getdata "mountdelta"]
      set mountrotation [server::getdata "mountrotation"]
    } else {
      log::info "maintaining the mount rotation."
    }

    set requestedaxisha    [axisha    $requestedmountha $requestedmountdelta $requestedmountrotation]
    set requestedaxisdelta [axisdelta $requestedmountha $requestedmountdelta $requestedmountrotation]
    
    variable zenithdistancelimit
    if {
      [astrometry::zenithdistance $requestedmountha $requestedmountdelta] > $zenithdistancelimit
    } {
      error "the requested position is below the zenith distance limit."
    } elseif {
      [astrometry::zenithdistance $mountha $requestedmountdelta] > $zenithdistancelimit
    } {
      log::info "moving first in HA to stay above the zenith distance limit."
      sendcommandandwait \
        [format "SET HA.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisha]]
      waituntilsafetomovebothaxes
      if {!$movetotrack} {
        log::info "moving in δ."
        sendcommandandwait \
          [format "SET DEC.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisdelta]]
      }
    } elseif {
      [astrometry::zenithdistance $requestedmountha $mountdelta] > $zenithdistancelimit
    } {
      log::info "moving first in δ to stay above the zenith distance limit."
      sendcommandandwait \
        [format "SET DEC.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisdelta]]
      waituntilsafetomovebothaxes
      if {!$movetotrack} {
        log::info "moving in HA."
        sendcommandandwait \
          [format "SET HA.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisha]]
      }
    } elseif {!$movetotrack} {
      log::info "moving simultaneously in HA and δ."
      sendcommandandwait [format \
        "SET HA.TARGETPOS=%.5f;DEC.TARGETPOS=%.5f" \
        [astrometry::radtodeg $requestedaxisha] \
        [astrometry::radtodeg $requestedaxisdelta] \
      ]
    }
    
    if {!$movetotrack} {
      waitwhilemoving
    }
    
  }
  
  proc parkhardware {} {
    variable hapark
    variable deltapark
    log::info "moving in δ to pole."
    sendcommandandwait "SET DEC.TARGETPOS=90"
    waitwhilemoving
    log::info [format "moving in HA to park at %+.1fd." [astrometry::radtodeg $hapark]]
    sendcommandandwait "SET HA.TARGETPOS=[astrometry::radtodeg $hapark]"
    waitwhilemoving
    log::info [format "moving in δ to park at %+.1fd." [astrometry::radtodeg $deltapark]]
    sendcommandandwait "SET DEC.TARGETPOS=[astrometry::radtodeg $deltapark]"
    waitwhilemoving
  }
  
  proc unparkhardware {} {
    variable haunpark
    variable deltaunpark
    log::info "moving in δ to pole."
    sendcommandandwait "SET DEC.TARGETPOS=90"
    waitwhilemoving
    log::info [format "moving in HA to unpark at %+.1fd." [astrometry::radtodeg $haunpark]]
    sendcommandandwait "SET HA.TARGETPOS=[astrometry::radtodeg $haunpark]"
    waitwhilemoving
    log::info [format "moving in δ to unpark at %+.1fd." [astrometry::radtodeg $deltaunpark]]
    sendcommandandwait "SET DEC.TARGETPOS=[astrometry::radtodeg $deltaunpark]"
    waitwhilemoving  
  }

  ######################################################################

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "initializing."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    if {![isoperational]} {
      log::info "attempting to change the controller state from [server::getdata "state"] to operational."
      coroutine::after 1000
      #sendcommandandwait "SET CABINET.POWER=0"
      #coroutine::after 1000
      sendcommandandwait "SET CABINET.STATUS.CLEAR=1"
      coroutine::after 1000
      sendcommandandwait "SET CABINET.POWER=1"
      coroutine::after 1000
      waituntiloperational
    }
    log::info "the controller state is operational."
    sendcommandandwait "SET DEC.OFFSET=0"
    sendcommandandwait "SET HA.OFFSET=0"
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    updaterequestedpositiondata false
    initializeactivitycommand
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "stopping."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "resetting."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
#    stophardware
    if {![isoperational]} {
      log::info "attempting to change the controller state from [server::getdata "state"] to operational."
      log::info "clearing errors."
      sendcommandandwait "SET CABINET.STATUS.CLEAR=1"
      waituntiloperational
    }
    variable emergencystopped
    if {$emergencystopped} {
      log::info "recovering from emergency stop."
      server::setactivity "parking"
      log::info "parking."
      parkhardware
      server::setactivity "unparking"
      log::info "unparking."
      unparkhardware
      set emergencystopped false
      log::info "finished recovering from emergency stop."
    }
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc rebootactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "rebooting."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    coroutine::after 1000
    log::info "switching off cabinet."
    sendcommandandwait "SET CABINET.POWER=0"
    coroutine::after 1000
    log::info "attempting to change the controller state from [server::getdata "state"] to operational."
    log::info "clearing errors."
    sendcommandandwait "SET CABINET.STATUS.CLEAR=1"
    coroutine::after 1000
    log::info "switching on cabinet."
    sendcommandandwait "SET CABINET.POWER=1"
    coroutine::after 1000
    waituntiloperational
    set end [utcclock::seconds]
    log::info [format "finished rebooting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
    updaterequestedpositiondata false
  }

  proc checktarget {activity expectedactivity} {
    if {[catch {client::checkactivity "target" $expectedactivity} message]} {
      controller::flushcommandqueue
#      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: $message"
    }
    if {![client::getdata "target" "withinlimits"]} {
      controller::flushcommandqueue
#      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: the target is not within the limits."
    }
  }

  proc moveactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "moving."
    if {[catch {checktarget "move" "idle"} message]} {
      log::warning $message
      return
    }
#    log::info "stopping."
#    stophardware
    movehardware false
    if {![acceptablehaerror] || ![acceptabledeltaerror]} {
      log::debug [format "mount error %.1fas E and %.1fas N." [astrometry::radtoarcsec [server::getdata "mounthaerror"]] [astrometry::radtoarcsec [server::getdata "mountdeltaerror"]]]
      movehardware false
    }
    checkhaerror    "after moving to fixed"
    checkdeltaerror "after moving to fixed"
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "parking."
#    stophardware
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc unparkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "unparking."
#     stophardware
    unparkhardware
    set end [utcclock::seconds]
    log::info [format "finished unparking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
    updaterequestedpositiondata false
  }

  proc addtrajectorypoints {seconds n dseconds} {
    variable freepoints
    set start [utcclock::seconds]
    log::debug "adding trajectory points."
    if {$n > $freepoints} {
      log::debug "only attempting to add $freepoints points."
      set n $freepoints
    }
    set halist    ""
    set deltalist ""
    set timelist  ""
    set i 0
    if {[catch {
      updaterequestedpositiondata false
      set requestedseconds        [utcclock::scan [server::getdata "requestedtimestamp"]]
      set requestedmountha        [server::getdata "requestedmountha"]
      set requestedmountdelta     [server::getdata "requestedmountdelta"]
      set requestedmountrotation  [server::getdata "requestedmountrotation"]
      set requestedmountharate    [server::getdata "requestedmountharate"]
      set requestedmountdeltarate [server::getdata "requestedmountdeltarate"]
      log::debug "adding $n trajectory points from [utcclock::format $requestedseconds] to [utcclock::format [expr {$requestedseconds + ($n - 1) * $dseconds}]]."
      while {$i < $n} {
        set futurerequestedseconds    [expr {$seconds + $i * $dseconds}]
        set futurerequestedmountha    [astrometry::foldradsymmetric [expr {$requestedmountha + ($futurerequestedseconds - $requestedseconds) * $requestedmountharate}]]
        set futurerequestedmountdelta [expr {$requestedmountdelta + ($futurerequestedseconds - $requestedseconds) * $requestedmountdeltarate}]
        set futurerequestedaxisha     [axisha    $futurerequestedmountha $futurerequestedmountdelta $requestedmountrotation]
        set futurerequestedaxisdelta  [axisdelta $futurerequestedmountha $futurerequestedmountdelta $requestedmountrotation]
        log::debug [format "trajectory point %d is %s %s %s %+.6fd %+.6fd" \
          $i \
          [utcclock::format $futurerequestedseconds] \
          [astrometry::formatha $futurerequestedmountha] \
          [astrometry::formatdelta $futurerequestedmountdelta] \
          [astrometry::radtodeg $futurerequestedaxisha] \
          [astrometry::radtodeg $futurerequestedaxisdelta]]
        if {$i > 0} {
          set halist    "$halist,"
          set deltalist "$deltalist,"
          set timelist  "$timelist,"
        } 
        set halist    [format "%s%.6f" $halist    [astrometry::radtodeg $futurerequestedaxisha   ]] 
        set deltalist [format "%s%.6f" $deltalist [astrometry::radtodeg $futurerequestedaxisdelta]] 
        set timelist  [format "%s%.4f" $timelist  $futurerequestedseconds]
        set i [expr {$i + 1}]
      }
    } message]} {
      error "unable to calculate new trajectory points: $message"
    }
    set command "SET "
    set command [format "%sHA.TRAJECTORY.BUFFER\[0-%d\].TIME=%s;"       $command [expr {$n - 1}] $timelist ]
    set command [format "%sHA.TRAJECTORY.BUFFER\[0-%d\].TARGETPOS=%s;"  $command [expr {$n - 1}] $halist   ]
    set command [format "%sDEC.TRAJECTORY.BUFFER\[0-%d\].TIME=%s;"      $command [expr {$n - 1}] $timelist ]
    set command [format "%sDEC.TRAJECTORY.BUFFER\[0-%d\].TARGETPOS=%s;" $command [expr {$n - 1}] $deltalist]
    set command [format "%sHA.TRAJECTORY.ADDPOINTS=%d;"                 $command $n]
    set command [format "%sDEC.TRAJECTORY.ADDPOINTS=%d;"                $command $n]
    log::debug "loading trajectory."
    sendcommandandwait $command
    log::debug [format "finished adding trajectory points after %.1f seconds." [utcclock::diff now $start]]
    return [expr {$seconds + $n * $dseconds}]
  }
  
  proc trackoroffsetactivitycommand {move} {
    set start [utcclock::seconds]
    maybeendtracking
    stophardware
    if {$move} {
      log::info "moving to track."
      movehardware true
    }
    if {[catch {checktarget "tracking" "tracking"} message]} {
      log::warning $message
      return
    }
    set trajectoryseconds [utcclock::seconds]
    set trajectorydseconds 2
    set trajectoryn 60
    set trajectorydfutureseconds 120
    set trajectoryseconds [addtrajectorypoints $trajectoryseconds $trajectoryn $trajectorydseconds]
    waituntilnottracking
    sendcommand "SET HA.TRAJECTORY.RUN=1"
    sendcommand "SET DEC.TRAJECTORY.RUN=1"
    maybestarttracking
    waituntiltracking
    log::info [format "started tracking after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "tracking"
    server::clearactivitytimeout
    while {true} {
      if {[catch {checktarget "tracking" "tracking"} message]} {
        log::warning $message
        return
      }
      if {[utcclock::diff $trajectoryseconds now] < $trajectorydfutureseconds} {
        set trajectoryseconds [addtrajectorypoints $trajectoryseconds $trajectoryn $trajectorydseconds]
      }
      coroutine::after 1000
    }
  }
  
  proc trackactivitycommand {} {
    trackoroffsetactivitycommand true
  }

  proc offsetactivitycommand {} {
    updaterequestedpositiondata true
    set mountrotation          [server::getdata "mountrotation"]
    set requestedmountrotation [server::getdata "requestedmountrotation"]
    if {$mountrotation == $requestedmountrotation} {
      set move false
    } else {
      set move true
    }
    trackoroffsetactivitycommand $move
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "mount.tcl"]
