########################################################################

# This file is part of the UNAM telescope control system.

# $Id: mountratir.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package require "astrometry"
package require "config"
package require "controller"
package require "client"
package require "log"
package require "pointing"
package require "server"
package require "utcclock"

package provide "mountratiroan" 0.0

config::setdefaultvalue "mount" "controllerhost"          "mount"
config::setdefaultvalue "mount" "controllerport"          10001
config::setdefaultvalue "mount" "allowedlsterror"         "2s"
config::setdefaultvalue "mount" "allowedpositionerror"    "4as"
config::setdefaultvalue "mount" "pointingmodelparameters" [dict create]
config::setdefaultvalue "mount" "allowedguideoffset"      "30as"

# The mount controller soft limits are 0.25d beyond the target
# controller limits.

config::setdefaultvalue "mount" "easthalimit"             "-05:21:00"
config::setdefaultvalue "mount" "westhalimit"             "+05:21:00"
config::setdefaultvalue "mount" "northdeltalimit"         "+56:15:00"
config::setdefaultvalue "mount" "southdeltalimit"         "-33:15:00"
config::setdefaultvalue "mount" "zenithdistancelimit"     "79.5d"

config::setdefaultvalue "mount" "hapark"                  "0h"
config::setdefaultvalue "mount" "deltapark"               $astrometry::latitude
config::setdefaultvalue "mount" "haunpark"                "0h"
config::setdefaultvalue "mount" "deltaunpark"             $astrometry::latitude

namespace eval "mount" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost          [config::getvalue "mount" "controllerhost"]
  variable controllerport          [config::getvalue "mount" "controllerport"]
  variable allowedlsterror         [astrometry::parseangle [config::getvalue "mount" "allowedlsterror"]]
  variable allowedpositionerror    [astrometry::parseangle [config::getvalue "mount" "allowedpositionerror"]]
  variable pointingmodelparameters [config::getvalue "mount" "pointingmodelparameters"]
  variable allowedguideoffset      [astrometry::parseangle [config::getvalue "mount" "allowedguideoffset"]] 
  variable easthalimit             [astrometry::parseangle [config::getvalue "mount" "easthalimit"]    "hms"]
  variable westhalimit             [astrometry::parseangle [config::getvalue "mount" "westhalimit"]    "hms"]
  variable northdeltalimit         [astrometry::parseangle [config::getvalue "mount" "northdeltalimit"] "dms"]
  variable southdeltalimit         [astrometry::parseangle [config::getvalue "mount" "southdeltalimit"] "dms"]
  variable zenithdistancelimit     [astrometry::parseangle [config::getvalue "mount" "zenithdistancelimit"]]
  variable hapark                  [astrometry::parseangle [config::getvalue "mount" "hapark"]]
  variable deltapark               [astrometry::parseangle [config::getvalue "mount" "deltapark"]]
  variable haunpark                [astrometry::parseangle [config::getvalue "mount" "haunpark"]]
  variable deltaunpark             [astrometry::parseangle [config::getvalue "mount" "deltaunpark"]]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::statuscommand               "TEL\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        400
  set controller::updatedata                  mount::updatecontrollerdata
  set controller::statusintervalmilliseconds  2000

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "state"                       ""
  server::setdata "mounttracking"               "unknown"
  server::setdata "mountha"                     ""
  server::setdata "mountalpha"                  ""
  server::setdata "mountdelta"                  ""
  server::setdata "mountazimuth"                ""
  server::setdata "mountzenithdistance"         ""
  server::setdata "mountrotation"               0
  server::setdata "withinlimits"                true
  server::setdata "lastmountha"                 ""
  server::setdata "lastmountalpha"              ""
  server::setdata "lastmountdelta"              ""
  server::setdata "timestamp"                   ""
  server::setdata "stoppedtimestamp"            ""
  server::setdata "settledtimestamp"            ""
  server::setdata "lastcorrectiontimestamp"     ""
  server::setdata "lastcorrectiondalpha"        ""
  server::setdata "lastcorrectionddelta"        ""
  server::setdata "settled"                     false
  server::setdata "settledtimestamp"            [utcclock::combinedformat now]
  server::setdata "mountmeaneasttrackingerror"  ""
  server::setdata "mountmeannorthtrackingerror" ""
  server::setdata "mountrmseasttrackingerror"   ""
  server::setdata "mountrmsnorthtrackingerror"  ""
  server::setdata "mountpveasttrackingerror"    ""
  server::setdata "mountpvnorthtrackingerror"   ""
  server::setdata "requestedmountrotation"      0
  server::setdata "mountrotation"               0

  variable settledelayseconds 1

variable fakecontrollererror false

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [string equal $controllerresponse ""] ||
      [string equal $controllerresponse "OK"] ||
      [string equal $controllerresponse "TEL EN MOVIMIENTO <<PARANDO>>"] ||
      [string equal $controllerresponse "la cuestion es cuadrada"] ||
      [string equal $controllerresponse "a cuestion es cuadrada"] ||
      [string equal $controllerresponse "da"]
    }
  }

  proc updatecontrollerdata {controllerresponse} {

    variable fakecontrollererror    
    if {$fakecontrollererror} {
      set fakecontrollererror false
      set controllerresponse "FAKE CONTROLLER ERROR"
    }

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]

    if {[isignoredcontrollerresponse $controllerresponse]} {
      return false
    }

    if {[scan $controllerresponse "AR : %d:%d:%f" h m s] == 3} {
      server::setdata "pendingtimestamp"  [utcclock::combinedformat now]
      server::setdata "pendingmountalpha" [astrometry::hmstorad "$h $m $s"]
      return false
    }
    if {[scan $controllerresponse "AH : - %d:%d:%f" h m s] == 3} {
      server::setdata "pendingmountha"    [astrometry::hmstorad "-$h $m $s"]
      return false
    }
    if {[scan $controllerresponse "AH :    %d:%d:%f" h m s] == 3} {
      server::setdata "pendingmountha"    [astrometry::hmstorad "$h $m $s"]
      return false
    }
    if {
      [scan $controllerresponse "DEC : - %d%*c%d\'%f\"" d m s] == 3
    } {
      server::setdata "pendingmountdelta" [astrometry::dmstorad "-$d $m $s"]
      return false
    }
    if {
      [scan $controllerresponse "DEC :  %d%*c%d\'%f\"" d m s] == 3
    } {
      server::setdata "pendingmountdelta" [astrometry::dmstorad "$d $m $s"]
      return false
    }
    if {[scan $controllerresponse "TS : %d:%d:%f" h m s] != 3} {
      log::error "unexpected controller response \"$controllerresponse\"."
      server::setactivity "error"
      log::info "stopping mount."
      controller::flushcommandqueue
      controller::pushcommand "NGUIA\n"
      server::setdata "mounttracking" false
      return true
    }

    set mountlst [astrometry::hmstorad "$h $m $s"]
    set mountlsterror [astrometry::foldradsymmetric [expr {$mountlst - [astrometry::last]}]]

    set lasttimestamp     [server::getdata "timestamp"]
    set lastmountha       [server::getdata "mountha"]
    set lastmountalpha    [server::getdata "mountalpha"]
    set lastmountdelta    [server::getdata "mountdelta"]

    set timestamp         [server::getdata "pendingtimestamp"]
    set mountha           [server::getdata "pendingmountha"]
    set mountalpha        [server::getdata "pendingmountalpha"]
    set mountdelta        [server::getdata "pendingmountdelta"]

    set mountazimuth        [astrometry::azimuth $mountha $mountdelta]
    set mountzenithdistance [astrometry::zenithdistance $mountha $mountdelta]

    set lastwithinlimits [server::getdata "withinlimits"]
    variable easthalimit
    variable westhalimit
    variable northdeltalimit
    variable southdeltalimit
    variable zenithdistancelimit
    if {
      ($mountha < $easthalimit) ||
      ($mountha > $westhalimit) ||
      ($mountdelta < $southdeltalimit) ||
      ($mountdelta > $northdeltalimit) ||
      ($mountzenithdistance > $zenithdistancelimit)
    } {
      if {$lastwithinlimits} {
        log::error "mount is not within the limits."
        server::setactivity "error"
        log::info "stopping mount."
        controller::flushcommandqueue
        controller::pushcommand "NGUIA\n"
        server::setdata "mounttracking" false
      }
      set withinlimits false
    } else {
      set withinlimits true
    }

    server::setstatus "ok"

    server::setdata "timestamp"           $timestamp
    server::setdata "mountha"             $mountha
    server::setdata "mountalpha"          $mountalpha
    server::setdata "mountdelta"          $mountdelta
    server::setdata "mountazimuth"        $mountazimuth
    server::setdata "mountzenithdistance" $mountzenithdistance
    server::setdata "withinlimits"        $withinlimits
    server::setdata "mountlst"            $mountlst
    server::setdata "mountlsterror"       $mountlsterror
    server::setdata "lasttimestamp"       $lasttimestamp
    server::setdata "lastmountha"         $lastmountha
    server::setdata "lastmountalpha"      $lastmountalpha
    server::setdata "lastmountdelta"      $lastmountdelta

    updaterequestedpositiondata


    set stoppedtimestamp  [server::getdata "stoppedtimestamp"]

    set stoppedhatolerance    [astrometry::parseangle "0.11s"]
    set stoppedalphatolerance [astrometry::parseangle "0.11s"]
    set stoppeddeltatolerance [astrometry::parseangle "0.11as"]

    if {[catch {expr {abs($mountha - $lastmountha) > $stoppedhatolerance}} hamoving]} {
      set hamoving 1
    }
    if {[catch {expr {abs($mountalpha - $lastmountalpha) > $stoppedalphatolerance}} alphamoving]} {
      set alphamoving 1
    }
    if {[catch {expr {abs($mountdelta - $lastmountdelta) > $stoppeddeltatolerance}} deltamoving]} {
      set deltamoving 1
    }
    
    set requestedactivity [server::getrequestedactivity]
    if {[string equal $requestedactivity "idle"] && ($hamoving || $deltamoving)} {
      set stoppedtimestamp ""
    } elseif {[string equal $requestedactivity "tracking"] && ($alphamoving || $deltamoving)} {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }

    variable settledelayseconds
    set settled          [server::getdata "settled"]
    set settledtimestamp [server::getdata "settledtimestamp"]
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      if {!$settled} {
        set settled true
        set settledtimestamp $timestamp
      }
    } else {
      if {$settled} {
        set settled false
        set settledtimestamp $timestamp
      }
    }

    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled
    server::setdata "settledtimestamp" $settledtimestamp
      
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

    set requestedactivity [server::getrequestedactivity]
    log::debug "continuing to update requested position for requested activity \"$requestedactivity\"."

    set mountha       [server::getdata "mountha"   ]
    set mountalpha    [server::getdata "mountalpha"]
    set mountdelta    [server::getdata "mountdelta"]
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

      set requestedobservedha        [client::getdata "target" "observedha"]
      set requestedobservedalpha     [client::getdata "target" "observedalpha"]
      set requestedobserveddelta     [client::getdata "target" "observeddelta"]
      set requestedobservedalpharate ""
      set requestedobserveddeltarate ""

      set mountdha    [mountdha    $requestedobservedha    $requestedobserveddelta $mountrotation]
      set mountddelta [mountddelta $requestedobservedalpha $requestedobserveddelta $mountrotation]

      set requestedmountha         [astrometry::foldradsymmetric [expr {$requestedobservedha + $mountdha}]]
      set requestedmountalpha      ""
      set requestedmountdelta      [expr {$requestedobserveddelta + $mountddelta}]

      set requestedmountalpharate  ""
      set requestedmountdeltarate  ""

      set mounthaerror    [expr {$mountha    - $requestedmountha   }]
      set mountalphaerror ""
      set mountdeltaerror [expr {$mountdelta - $requestedmountdelta}]

    } else {

      log::debug "updating requested position in the last branch."

      set requestedobservedha        ""
      set requestedobservedalpha     ""
      set requestedobserveddelta     ""
      set requestedobservedalpharate ""
      set requestedobserveddeltarate ""

      set requestedmountha        ""
      set requestedmountalpha     ""
      set requestedmountdelta     ""
      set requestedmountalpharate ""
      set requestedmountdeltarate ""

      set mounthaerror    ""
      set mountalphaerror ""
      set mountdeltaerror ""

    }

    server::setdata "requestedobservedha"        $requestedobservedha
    server::setdata "requestedobservedalpha"     $requestedobservedalpha
    server::setdata "requestedobserveddelta"     $requestedobserveddelta
    server::setdata "requestedobservedalpharate" $requestedobservedalpharate
    server::setdata "requestedobserveddeltarate" $requestedobserveddeltarate

    server::setdata "requestedmountha"        $requestedmountha
    server::setdata "requestedmountalpha"     $requestedmountalpha
    server::setdata "requestedmountdelta"     $requestedmountdelta
    server::setdata "requestedmountalpharate" $requestedmountalpharate
    server::setdata "requestedmountdeltarate" $requestedmountdeltarate

    server::setdata "mounthaerror"    $mounthaerror
    server::setdata "mountalphaerror" $mountalphaerror
    server::setdata "mountdeltaerror" $mountdeltaerror

    log::debug "finished updating requested position."
  }

  ######################################################################

  proc mountdha {ha delta rotation} {
    variable pointingmodelparameters
    return [pointing::modeldha $pointingmodelparameters $ha $delta]
  }

  proc mountdalpha {alpha delta rotation {seconds "now"}} {
    set ha [astrometry::ha $alpha $seconds]
    variable pointingmodelparameters
    return [pointing::modeldalpha $pointingmodelparameters $ha $delta]
  }

  proc mountddelta {alpha delta rotation {seconds "now"}} {
    set ha [astrometry::ha $alpha $seconds]
    variable pointingmodelparameters
    return [pointing::modelddelta $pointingmodelparameters $ha $delta]
  }

  proc updatepointingmodel {dIH dID rotation} {
    variable pointingmodelparameters
    set pointingmodelparameters [pointing::updateabsolutemodel $pointingmodelparameters $dIH $dID]
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
  
  proc checklsterror {when} {
    variable allowedlsterror
    set lsterror [server::getdata "mountlsterror"]
    if {abs($lsterror) > $allowedlsterror} {
       log::warning "mount LST error is [astrometry::radtohms $lsterror 2 true] $when."
    }    
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

  proc formatcontrolleralpha {alpha} {
    astrometry::radtohms $alpha 2 false " "
  }

  proc formatcontrollerdelta {delta} {
    set dms [astrometry::radtodms [expr {abs($delta)}] 1 true " "]
    # Make sure negative angles are understood by the consola.
    if {$delta < 0} {
      regsub -all -- "\[+ \]" $dms " -" dms
    }
    return $dms
  }

  proc formatcontrollerha {ha} {
    set hms [astrometry::radtohms [expr {abs($ha)}] 1 true " "]
    # Make sure negative angles are understood by the consola.
    if {$ha < 0} {
      regsub -all -- "\[+ \]" $hms " -" hms
    }
    return $hms
  }

  ######################################################################
  
  # The preload pulls the telescope to the south. Therefore, in theory we
  # always want to approach a position from the south. However, south of
  # the zenith this does not seem to work very well and the telescope
  # seems to drift to the north. Therefore, north of +22.5d we always
  # approach from the south and south of +22.5d we always approach from the
  # south.
  
  variable backlashdeltatransition [astrometry::parseangle "+22.5d"]

  proc backlashalphaoffset {} {
    return 0
  }

  proc backlashdeltaoffset {} {
    variable backlashdeltatransition
    set requestedmountdelta [server::getdata "requestedmountdelta"]
    if {$requestedmountdelta > $backlashdeltatransition} {
      return [astrometry::parseangle "-10am"]
    } else {
      return [astrometry::parseangle "+10am"]
    }
  }

  proc needtomitigatebacklash {} {
    variable backlashdeltatransition
    set requestedmountdelta [server::getdata "requestedmountdelta"]
    set mountdelta          [server::getdata "mountdelta"]
    if {$requestedmountdelta > $backlashdeltatransition} {
      return [expr {$requestedmountdelta < $mountdelta}]
    } else {
      return [expr {$requestedmountdelta > $mountdelta}]
    }
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

  variable meaninclinometerstolerance [astrometry::degtorad 0.2]
  variable meaninclinometersha
  variable meaninclinometersdelta
  variable meaninclinometersazimuth
  variable meaninclinometerszenithdistance
  
  proc getmeaninclinometersposition {} {
    
    set start [utcclock::seconds]
    log::debug [format "getmeaninclinometersposition: determining mean position."]
    
    
    variable meaninclinometerstolerance
    set tolerance $meaninclinometerstolerance

    set n 0
    set sumha          0.0
    set sumdelta       0.0
    set sumsquareha    0.0
    set sumsquaredelta 0.0
    
    set timestamp ""

    while {true} {

      coroutine::after 100

      if {[catch {client::update "inclinometers"} message]} {
        log::warning "unable to obtain inclinometers data: $message"
        continue
      }
      
      if {[string equal $timestamp [client::getdata "inclinometers" "timestamp"]]} {
        continue
      }
      set timestamp [client::getdata "inclinometers" "timestamp"]

      set ha    [client::getdata "inclinometers" "ha"]
      set delta [client::getdata "inclinometers" "delta"]
      
      set n              [expr {$n + 1}]
      set sumha          [expr {$sumha          + $ha            }]
      set sumdelta       [expr {$sumdelta       + $delta         }]
      set sumsquareha    [expr {$sumsquareha    + $ha * $ha      }]
      set sumsquaredelta [expr {$sumsquaredelta + $delta * $delta}]
      
      set meanha    [expr {$sumha    / $n}]
      set meandelta [expr {$sumdelta / $n}]
      
      log::debug [format "getmeaninclinometersposition: n = %d." $n]
      log::debug [format "getmeaninclinometersposition: ha = %.2fd delta = %.2fd." [astrometry::radtodeg $ha] [astrometry::radtodeg $delta]]
      log::debug [format "getmeaninclinometersposition: meanha = %.2fd meandelta = %.2fd." [astrometry::radtodeg $meanha] [astrometry::radtodeg $meandelta]]

      if {$n > 1} {
        set sigmameanha    [expr {sqrt(($sumsquareha    - $n * $meanha    * $meanha   ) / ($n - 1) / $n)}]
        set sigmameandelta [expr {sqrt(($sumsquaredelta - $n * $meandelta * $meandelta) / ($n - 1) / $n)}]  
        log::debug [format "getmeaninclinometersposition: sigmameanha = %.2fd sigmameandelta = %.2fd." [astrometry::radtodeg $sigmameanha] [astrometry::radtodeg $sigmameandelta]]
      }
      
      if {$n > 10 && $sigmameanha <= $tolerance && $sigmameandelta <= $tolerance} {
        break
      }
      
    }
    
    log::debug [format "getmeaninclinometersposition: mean position is HA = %+.2fd and delta = %+.2fd." [astrometry::radtodeg $meanha] [astrometry::radtodeg $meandelta]]
    log::debug [format "getmeaninclinometersposition: achieving tolerance of %.2fd required %d samples." [astrometry::radtodeg $tolerance] $n]
    set sigmaha    [expr {$sigmameanha    * sqrt($n)}]
    set sigmadelta [expr {$sigmameandelta * sqrt($n)}]
    log::debug [format "getmeaninclinometersposition: estimated errors in a single sample are %.2fd in HA and %.2fd in delta." [astrometry::radtodeg $sigmaha] [astrometry::radtodeg $sigmadelta]]
    
    variable meaninclinometersha
    variable meaninclinometersdelta
    variable meaninclinometersazimuth
    variable meaninclinometerszenithdistance
    
    set meaninclinometersha             $meanha
    set meaninclinometersdelta          $meandelta
    set meaninclinometersazimuth        [astrometry::azimuth        $meanha $meandelta]
    set meaninclinometerszenithdistance [astrometry::zenithdistance $meanha $meandelta]

    set end [utcclock::seconds]
    log::debug [format "getmeaninclinometersposition: finished determining mean position after %.1f seconds." [utcclock::diff $end $start]]
      
    return
  }

  ######################################################################
  
  proc settle {} {
    log::debug "settling."
    coroutine::yield
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  proc resettle {} {
    log::debug "resettling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastmountha"      ""
    server::setdata "lastmountalpha"   ""
    server::setdata "lastmountdelta"   ""
    server::setdata "settled"          false
    settle
  }
  
  proc startactivitycommand {} {
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    stopactivitycommand
  }

  variable lsttoleranceseconds 1.0
  variable zenithdistancetolerance [astrometry::degtorad 1.0]
  
  proc synchronizelast {} {
    # Synchronize clock.
    server::setdata "mountclockutcoffset" 0.0
    while {true} {
      set clockoffsetseconds [server::getdata "mountclockutcoffset"]
      log::debug [format "synchronizelast: setting the mount clock with an offset of %+.1f seconds from UTC." $clockoffsetseconds]
      set seconds [expr {[clock seconds] + $clockoffsetseconds}]
      set iseconds [expr {int($seconds)}]
      set fseconds [expr {$seconds - int($seconds)}]
      set fseconds [format "%.1f" $fseconds]
      if {$fseconds == 1.0} {
        set fseconds 0.0
        set isecond [expr {$iseconds + 1}]
      }
      set fseconds [string range $fseconds 1 end]
      controller::sendcommand \
        [clock format $iseconds -format "MDA %m %d %y T_LOCAL %H %M %S$fseconds\n" -gmt true]      
      settle
      resettle
      set mountlsterror [server::getdata "mountlsterror"]
      set mountlsterrorseconds [expr {[astrometry::radtohr $mountlsterror] * 3600}]
      log::debug "synchronizelast: LST error is [format "%+.1f" $mountlsterrorseconds]s."
      variable lsttoleranceseconds
      if {abs($mountlsterrorseconds) < $lsttoleranceseconds} {
        log::debug "synchronizelast: LST is synchronized."
        break
      }
      set mountclockutcoffset [server::getdata "mountclockutcoffset"]
      set mountclockutcoffset [expr {$mountclockutcoffset - $mountlsterrorseconds}]
      server::setdata "mountclockutcoffset" $mountclockutcoffset
    }

  }
  
  proc findzenithapproximately {} {
    # Find approximate zenith using inclinometers.
    while {true} {
      settle
      resettle
      getmeaninclinometersposition
      variable meaninclinometersha
      variable meaninclinometersdelta
      variable meaninclinometerszenithdistance
      set ha             $meaninclinometersha
      set delta          $meaninclinometersdelta
      set zenithdistance $meaninclinometerszenithdistance     
      log::debug [format "findzenithapproximately: zenith distance is %.1fd." [astrometry::radtodeg $zenithdistance]]
      variable zenithdistancetolerance
      if {$zenithdistance < $zenithdistancetolerance} {
        log::debug [format "findzenithapproximately: zenith distance is within tolerance of %.1fd." [astrometry::radtodeg $zenithdistancetolerance]]
        break
      }
      set dha    $ha
      set ddelta [expr {$delta - [astrometry::latitude]}]
      set min [astrometry::degtorad -15]
      set max [astrometry::degtorad +15]
      set dha    [expr {-max($min,min($max,$dha))}]
      set ddelta [expr {-max($min,min($max,$ddelta))}]
      log::debug [format "findzenithapproximately: moving %+.2fd in HA and %+.2fd in delta." [astrometry::radtodeg $dha] [astrometry::radtodeg $ddelta]]
      controller::flushcommandqueue
      controller::sendcommand "LISTO\n"
      controller::sendcommand "AH [formatcontrollerha $dha] FIJO_DEC [formatcontrollerdelta [expr {[astrometry::latitude] + $ddelta}]]\n"
    }    

    controller::flushcommandqueue
    controller::sendcommand "LISTO\n"

  }
  
  proc findzenithprecisely {} {
    return
    
    set limit [astrometry::parseangle "5d"]

    # Find more precise zenith using the proximity sensors.
    set dha    [astrometry::parseangle "-2d"]
    set ddelta [astrometry::parseangle "-2d"]
    log::debug [format "findzenithprecisely: moving to %+.6fd in HA and %+.6fd in delta." [astrometry::radtodeg $dha] [astrometry::radtodeg $ddelta]]
    controller::sendcommand "AH [formatcontrollerha $dha] FIJO_DEC [formatcontrollerdelta [expr {[astrometry::latitude] + $ddelta}]]\n"

    for {set i 1} {$i <= 6} {incr i} {
      log::debug "findzenithprecisely: step index is $i."
      set step [astrometry::degtorad [expr {1.0 / pow(2.0,$i)}]]
      if {$i % 2 == 1} {
        set direction "forward"
      } else {
        set direction "backward"
      }
      while {true} {
        if {abs($dha) > $limit || abs($ddelta) > $limit} {
          error "unable to find the zenith precisely."
        }
        resettle
        if {[catch {client::update "inclinometers"} message]} {
        log::warning "findzenithprecisely: unable to obtain inclinometers data: $message"
          continue
        }
        set haswitch    [client::getdata "inclinometers" "haswitch"   ]
        set deltaswitch [client::getdata "inclinometers" "deltaswitch"]
        log::debug "findzenithprecisely: haswitch = $haswitch and deltaswitch = $deltaswitch."
        if {[string equal $direction "forward"]} {
          if {[string equal $haswitch "on"] && [string equal $deltaswitch "on"]} {
            break
          }
          if {[string equal $deltaswitch "off"]} {
            set ddelta [expr {$ddelta + $step}]
          }
          if {[string equal $haswitch "off"]} {
            set dha [expr {$dha + $step}]
          }
        } else {
          if {[string equal $haswitch "off"] && [string equal $deltaswitch "off"]} {
            break
          }
          if {[string equal $deltaswitch "on"]} {
            set ddelta [expr {$ddelta - $step}]
          }
          if {[string equal $haswitch "on"]} {
            set dha [expr {$dha - $step}]
          }
        }
        log::debug [format "findzenithprecisely: moving to %+.6fd in HA and %+.6fd in delta." [astrometry::radtodeg $dha] [astrometry::radtodeg $ddelta]]
        controller::flushcommandqueue
        controller::sendcommand "AH [formatcontrollerha $dha] FIJO_DEC [formatcontrollerdelta [expr {[astrometry::latitude] + $ddelta}]]\n"
      }
    }

    controller::flushcommandqueue
    controller::sendcommand "LISTO\n"

    resettle

    set dha 0
    set ddelta 0

# 2012-06-17 06:49:34.286 telescope: pointing error is −3836.8as E and +1345.0as N.
#    set dha    [astrometry::parseangle "+4156.8as"]
#    set ddelta [astrometry::parseangle "+1375.0as"]

# 2012-09-26 03:51:50.689 telescope[11190]: info: pointing error is -3984.3as E and -500.5as N.
#    set dha    [expr {[astrometry::parseangle "+3984.3as"] / cos([astrometry::latitude])}]
#    set ddelta [astrometry::parseangle "-500.5as"]

    set dha    [expr {[astrometry::parseangle "+3720as"] / cos([astrometry::latitude])}]
    set ddelta [astrometry::parseangle "-400as"]

    controller::flushcommandqueue
    controller::sendcommand "AH [formatcontrollerha $dha] FIJO_DEC [formatcontrollerdelta [expr {[astrometry::latitude] + $ddelta}]]\n"

    resettle 
     
    controller::flushcommandqueue
    controller::sendcommand "LISTO\n"
    
  }
  
  proc initializeactivitycommand {} {
    updaterequestedpositiondata
    variable pointingmodelparameters
    set pointingmodelparameters [config::getvalue "mount" "pointingmodelparameters"]
    stopactivitycommand    
    synchronizelast
    checklsterror "after synchronizing clock"
    findzenithapproximately
  }
  
  proc openactivitycommand {} {
    updaterequestedpositiondata
    initializeactivitycommand
    findzenithprecisely
  }
  
  proc stopactivitycommand {} {
    updaterequestedpositiondata
    controller::flushcommandqueue
    controller::sendcommand "NGUIA\n"
    server::setdata "mounttracking" false
    settle
    resettle
  }
  
  proc resetactivitycommand {} {
    updaterequestedpositiondata
    controller::flushcommandqueue
    controller::sendcommand "NGUIA\n"
    server::setdata "mounttracking" false
    settle
    resettle
  }
  
  proc rebootactivitycommand {} {
    error "rebooting is not implemented."
  }
  
  proc preparetomoveactivitycommand {} {
    updaterequestedpositiondata
  }
  
  proc checktarget {activity expectedactivity} {
    if {[catch {client::checkactivity "target" $expectedactivity} message]} {
      controller::flushcommandqueue
      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: $message"
    }
    if {![client::getdata "target" "withinlimits"]} {
      controller::flushcommandqueue
      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: the target is not within the limits."
    }
  }
  
  proc moveactivitycommand {} {
    if {[catch {checktarget "move" "idle"} message]} {
      log::warning $message
      return
    }
    updaterequestedpositiondata
    set requestedmountha    [server::getdata "requestedmountha"]
    set requestedmountdelta [server::getdata "requestedmountdelta"]
    log::debug "requestedmountha is \"$requestedmountha\"."
    log::debug "requestedmountdelta is \"$requestedmountdelta\"."
    controller::sendcommand "AH [formatcontrollerha $requestedmountha] FIJO_DEC [formatcontrollerdelta $requestedmountdelta]\n"
    server::setdata "mounttracking" false
    settle
    if {![acceptablehaerror] || ![acceptabledeltaerror]} {
      resettle
      log::debug [format "mount error %.1fas E and %.1fas N." [astrometry::radtoarcsec [server::getdata "mounthaerror"]] [astrometry::radtoarcsec [server::getdata "mountdeltaerror"]]]
    }
    checkhaerror    "after moving to fixed"
    checkdeltaerror "after moving to fixed"
  }
  
  proc preparetotrackactivitycommand {} {
    updaterequestedpositiondata
  }
  
  variable trackingintervalseconds 100

  proc trackactivitycommand {} {
    checklsterror "before moving to track"
    if {[catch {checktarget "tracking" "tracking"} message]} {
      log::warning $message
      return
    }
    updaterequestedpositiondata
    set requestedmountalpha [server::getdata "requestedmountalpha"]
    set requestedmountdelta [server::getdata "requestedmountdelta"]
    if {[needtomitigatebacklash]} {
      set requestedmountalpha [expr {$requestedmountalpha + [backlashalphaoffset]}]
      set requestedmountdelta [expr {$requestedmountdelta + [backlashdeltaoffset]}]
      controller::sendcommand "AR [formatcontrolleralpha $requestedmountalpha] DEC [formatcontrollerdelta $requestedmountdelta] MSC\n"
      settle
    }
    if {[catch {checktarget "tracking" "tracking"} message]} {
      log::warning $message
      return
    }
    updaterequestedpositiondata
    set requestedmountalpha [server::getdata "requestedmountalpha"]
    set requestedmountdelta [server::getdata "requestedmountdelta"]
    if {[shouldoffsettotrack]} {
      set mountalpha [server::getdata "mountalpha"]
      set mountdelta [server::getdata "mountdelta"]
      set alphaoffset [expr {($requestedmountalpha - $mountalpha) * cos($mountdelta)}]
      set deltaoffset [expr {($requestedmountdelta - $mountdelta)}]
      offsetcommand send $alphaoffset $deltaoffset
    } else {
      controller::sendcommand "AR [formatcontrolleralpha $requestedmountalpha] DEC [formatcontrollerdelta $requestedmountdelta] MSC\n"
      server::setdata "mounttracking" true
    }
    set trackingtimestamp [utcclock::combinedformat now]
    settle
    if {![acceptablealphaerror] || ![acceptabledeltaerror]} {
      resettle
      log::debug [format "mount error %.1fas E and %.1fas N" [astrometry::radtoarcsec [server::getdata "mountalphaerror"]] [astrometry::radtoarcsec [server::getdata "mountdeltaerror"]]]
    }
    checklsterror "after moving to track"
    checkalphaerror "after moving to track"
    checkdeltaerror "after moving to track"
    server::setactivity "tracking"
    server::clearactivitytimeout
    while {true} {
      if {[catch {checktarget "tracking" "tracking"} message]} {
        log::warning $message
        return
      }
      variable trackingintervalseconds
      set diff [utcclock::diff now $trackingtimestamp]      
      if {$diff >= $trackingintervalseconds} {
        checklsterror "while tracking"
        set trackingtimestamp [utcclock::combinedformat now]
        set requestedmountalpharate [server::getdata "requestedmountalpharate"]
        set requestedmountdeltarate [server::getdata "requestedmountdeltarate"]
        set dalpha [expr {$requestedmountalpharate * $diff}]
        set ddelta [expr {$requestedmountdeltarate * $diff}]
        log::debug [format "offsetting %+.2fas E and %+.2fas N to correct tracking." [astrometry::radtoarcsec $dalpha] [astrometry::radtoarcsec $ddelta]]
        offsetcommand send $dalpha $ddelta
      }
      coroutine::after 1000
    }
    controller::flushcommandqueue
    controller::sendcommand "NGUIA\n"
    server::setdata "mounttracking" false
    server::setrequestedactivity "idle"
  }
  
  proc offsetactivitycommand {} {
    trackactivitycommand
  }

  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "parking."
    variable hapark
    variable deltapark
    controller::sendcommand "AH [formatcontrollerha $hapark] FIJO_DEC [formatcontrollerdelta $deltapark]\n"
    server::setdata "mounttracking" false
    settle
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc unparkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "unparking."
    variable haunpark
    variable deltaunpark
    controller::sendcommand "AH [formatcontrollerha $haunpark] FIJO_DEC [formatcontrollerdelta $deltaunpark]\n"
    server::setdata "mounttracking" false
    settle
    set end [utcclock::seconds]
    log::info [format "finished unparking after %.1f seconds." [utcclock::diff $end $start]]
  }

  
  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "mount.tcl"]
