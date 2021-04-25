########################################################################

# This file is part of the UNAM telescope control system.

# $Id: telescoperatir.tcl 3613 2020-06-20 20:21:43Z Alan $

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
package require "safetyswitch"
package require "finders"

package provide "telescoperatir" 0.0

namespace eval "telescope" {

  variable svnid {$Id}

  ######################################################################
  
  variable finders [config::getvalue "telescope" "finders"]

  variable components [concat \
    $finders \
    { covers dome executor gcntan guider power inclinometers 
      moon mount owsensors secondary shutters sun target 
      weather } \
  ]
    
  server::setdata "pointingmode"            "finder"
  server::setdata "pointingtolerance"       [astrometry::parseangle "5as"]
  server::setdata "pointingaperture"        "default"
  server::setdata "guidingmode"             "finder"
  server::setdata "timestamp"               [utcclock::combinedformat now]

  ######################################################################

  proc getpowercontacts {} {
    client::update "shutters"
    if {[string equal "error" [client::getdata "shutters" "activity"]]} {
      error "shutters activity is \"error\"."
    }
    return [client::getdata "shutters" "powercontacts"]
  }
  
  proc stopserver {component} {
    if {[catch {exec "[directories::prefix]/bin/stopserver" "$component"} message]} {
      log::debug "stopping server failed: $message"
    }
  }
  
  proc startserver {component} {
    exec "[directories::prefix]/bin/startserver" "$component"
  }
  
  proc switchon {outletgroup} {
    client::wait "power"
    while {[catch {client::request "power" "switchon $outletgroup"} message]} {
      log::debug "client::request failed: $message"
      coroutine::after 1000
    }
    coroutine::after 1000
    client::wait "power"
  }

  proc switchoff {outletgroup} {
    client::wait "power"
    while {[catch {client::request "power" "switchoff $outletgroup"} message]} {
      log::debug "client::request failed: $message"
      coroutine::after 1000
    }
    coroutine::after 1000
    client::wait "power"
  }

  proc reboot {outletgroup} {
    log::info "rebooting $outletgroup."
    client::wait "power"
    while {[catch {client::request "power" "reboot $outletgroup"} message]} {
      log::debug "client::request failed: $message"
      coroutine::after 1000
    }
    client::wait "power"
    log::info "finished rebooting $outletgroup."
  }
  
  proc ringalarmbell {} {
    log::info "ringing the alarm bell."
    switchon "alarm-bell"
    coroutine::after 10000
    switchoff "alarm-bell"    
    log::info "finished ringing the alarm bell."
  }
  
  proc startactivitycommand {} {

    log::info "starting."
    
    # Because of interdependence of certain servers on others, we need
    # to stop the moon, sun, target, and weather server last
    # (in that order) and start them first (in the reverse order).
    
#     server::setdata "pointingmode" "none"
#     server::setdata "guidingmode" "none"
#     server::setdata "timestamp" [utcclock::combinedformat now]
#     
#     foreach {component wait} {
#       power          true
#       weather      false
#       target       true
#       moon         true
#       sun          true
#       covers       true
#       dome         true
#       mount        true
#       secondary    true
#       shutters     true
#       nefinder     true
#       sefinder     true
#       guider       true
#     } {
#       startup${component}activitycommand info $wait
#     }
#     
#     foreach outletgroup {
#       dome-fans
#       finder-ccd-pump
#       science-ccd-pump
#     } {
#       switchoff $outletgroup
#     }

    log::info "finished starting."
    
  }

  proc shutdownactivitycommand {} {
    
    log::info "shutting down."
    
    server::setdata "pointingmode" "none"
    server::setdata "guidingmode" "none"
    server::setdata "timestamp" [utcclock::combinedformat now]

    variable finders
        
    foreach component [concat $finders {
      covers dome guider inclinometers mount moon
      secondary shutters sun target weather
    }] {
      shutdown${component}activitycommand info
    }
    
    foreach outletgroup {
      dome-fans
      finder-ccd-pump
    } {
      switchoff $outletgroup
    }
    
    shutdownpoweractivitycommand info
    
    log::info "finished shutting down."
  }

  proc resetall {} {
    variable finders
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::request $component "reset"
    }
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::wait $component
    }
  }

  proc stopall {} {
    variable finders
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::request $component "stop"
    }
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::wait $component
    }
  }

  proc switchlightsonactivitycommand {} {
    log::info "switching on the lights."
    switchon dome-lights
    switchon hallway-light
    log::info "finished switching on the lights."
  }

  proc switchlightsoffactivitycommand {} {
    log::info "switching off the lights."
    switchoff dome-lights
    switchoff hallway-light
    log::info "finished switching off the lights."
  }

  proc stopactivitycommand {} {
    log::info "stopping."
    stopall
    log::info "finished stopping."
  }
    
  proc resetactivitycommand {} {
    log::info "resetting."
    resetall
    server::handlereset
    log::info "finished resetting."
  }    

  proc initializeactivitycommand {} {
    
    log::info "initializing."
    
    switchlightsonactivitycommand
    ringalarmbell
    
    server::setdata "pointingmode" "none"
    server::setdata "guidingmode" "none"
    server::setdata "timestamp" [utcclock::combinedformat now]

    variable finders
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::waituntilstarted $component
    }
    foreach component [concat $finders {mount dome guider secondary shutters covers target}] {
      client::request $component "stop"
    }
    foreach component [concat $finders {mount dome secondary shutters covers target}] {
      client::wait $component
    }
    
    foreach component [concat $finders {mount dome secondary shutters covers}] {
      initialize${component}activitycommand
    }
    
    log::info "finished initializing."
  }
  
  proc openactivitycommand {} {
    
    log::info "opening."

    switchlightsonactivitycommand
    ringalarmbell

    log::info "switching on the finder CCD pump."
    switchon finder-ccd-pump
    log::info "finished switching on the finder CCD pump."
    log::info "setting finder CCD coolers to on."
    variable finders
    foreach finder $finders {
      log::info "setting $finder cooler."
      client::request $finder "setcooler on"
    }

    switchon mount-motors
    client::request "dome" "stop"
    client::wait "dome"
    client::request "mount" "preparetomove" 
    client::wait "mount"
    client::request "target" "movetoidle"
    client::wait "target"
    log::info "opening mount."
    client::request "mount" "open"
    movedometocontacts
    log::info "opening shutters."
    client::request "shutters" "open"
    client::wait "shutters"
    client::wait "mount"
    client::request "inclinometers" "suspend"
    client::wait "inclinometers"
    log::info "opening covers."
    client::request "covers" "open"
    client::wait "covers"
    client::request "inclinometers" "resume"
    client::wait "inclinometers"
    switchon dome-fans
    server::setdata "pointingmode" "finder"
    server::setdata "guidingmode" "finder"
    server::setdata "timestamp" [utcclock::combinedformat now]
    
    switchlightsoffactivitycommand

    log::info "finished opening."
  }
  
  proc opentocoolactivitycommand {} {
    openactivitycommand
  }

  proc closeactivitycommand {} {
    
    log::info "closing."

    switchlightsonactivitycommand
    ringalarmbell

    log::info "stopping guiding."
    client::request "guider" "stop"
    variable finders
    foreach finder $finders {
      client::request $finder "stop"
    }

    server::setdata "pointingmode" "none"
    server::setdata "guidingmode" "none"
    server::setdata "timestamp" [utcclock::combinedformat now]

    log::info "setting finder CCD coolers to following."
    variable finders
    foreach finder $finders {
      log::info "setting $finder cooler."
      client::request $finder "setcooler following"
    }
    
    client::request "dome" "stop"
    client::wait "dome"

    log::info "moving mount to zenith."
    client::request "mount" "preparetomove"
    client::wait "mount"
    client::request "target" "movetoidle"
    client::wait "target"
    client::request "mount" "move"
    client::wait "mount"

    client::request "inclinometers" "suspend"
    client::wait "inclinometers"
    log::info "closing covers."
    client::request "covers" "close"

    movedometocontacts

    client::wait "covers"
    client::request "inclinometers" "resume"
    client::wait "inclinometers"

    log::info "closing shutters."
    client::request "shutters" "close"
    switchoff dome-fans
    client::wait "shutters"

    log::info "moving dome to parked position."
    client::request "dome" "preparetomove"
    client::wait "dome"
    client::request "dome" "move parked"
    client::wait "dome"

    client::wait "mount"
    switchoff mount-motors

    switchoff finder-ccd-pump

    log::info "finished closing."
  }
  
  proc emergencycloseactivitycommand {} {

    log::info "closing (emergency)."

    catch {switchlightsonactivitycommand}
    catch {ringalarmbell}
        
    catch {resetall}
    catch {client::request "inclinometers" "suspend"}
    log::info "closing covers."
    catch {client::request "covers" "close"}
    catch {movedometocontacts}
    log::info "closing shutters."
    catch {client::request "shutters" "close"}
    catch {client::wait "shutters"}
    catch {client::wait "covers"}
    catch {client::request "inclinometers" "resume"}

    closeactivitycommand
    
    log::info "finished closing (emergency)."

  }
    
  proc moveactivitycommand {ha delta} {
    log::info "moving."
    client::request "guider" "stop"
    client::request "mount" "preparetomove"
    client::wait "mount"
    client::request "dome" "preparetomove"
    client::wait "dome"
    client::request "target" "move $ha $delta"
    client::wait "target"
    client::request "dome" "move"
    if {![client::getdata "target" "withinlimits"]} {
      log::error "the target is not within the limits."
      client::request "mount" "stop"
      client::wait "mount"
      return
    }
    client::request "mount" "move"
    client::request "secondary" "movewithoutcheck z0"
    client::wait "mount"
    client::wait "secondary"
    client::request "secondary" "move z0"
    client::wait "secondary"
    client::wait "dome"
    log::info "finished moving."
  }
  
  proc parkactivitycommand {} {
    log::info "parking."
    client::request "guider" "stop"
    client::request "mount" "preparetomove"
    client::wait "mount"
    client::request "dome" "preparetomove"
    client::wait "dome"
    client::request "target" "movetoparked"
    client::wait "target"
    client::request "dome" "move parked"
    if {![client::getdata "target" "withinlimits"]} {
      log::error "the target is not within the limits."
      client::request "mount" "stop"
      client::wait "mount"
      return
    }
    client::request "mount" "move"
    client::wait "mount"
    client::wait "dome"
    log::info "finished parking."
  }
  
  variable lastalphaoffset
  variable lastdeltaoffset
  variable lastpointingaperture
  variable lastguidingmode  
  
  proc ratirtrackactivitycommand {alpha delta equinox alphaoffset deltaoffset epoch alpharate deltarate} {
    log::info "moving."
    set pointingmode     [server::getdata "pointingmode"]
    set guidingmode      [server::getdata "guidingmode"]
    set pointingaperture [server::getdata "pointingaperture"]
    client::request "guider" "stop"
    variable finders
    foreach finder $finders {
      client::request $finder "stop"
    }
    client::request "mount" "preparetotrack"
    client::wait "mount"
    client::request "dome" "preparetotrack"
    client::wait "dome"
    client::request "target" "track $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $pointingaperture"
    client::wait "target"
    client::request "dome" "track"
    if {![client::getdata "target" "withinlimits"]} {
      log::warning "the target is not within the limits."
      client::request "mount" "stop"
      client::wait "mount"
      return
    }
    client::request "mount" "track"
    client::request "secondary" "movewithoutcheck z0"
    client::wait "dome"
    client::wait "mount"
    if {[string equal $pointingmode "finder"]} {
      foreach finder $finders {
        client::wait $finder
      }
      finders::getfinderastrometry
      set finder $finders::solvedfinder
      if {[string equal $finder ""]} {
        log::warning "unable to correct pointing."
      } else {
        set alpha [client::getdata $finder "mountobservedalpha"]
        set delta [client::getdata $finder "mountobserveddelta"]
        client::request "mount" "correct [astrometry::radtohms $alpha 2 false] [astrometry::radtodms $delta 1 true] observed"
        client::update "mount"
        set alphaoffset [expr {[client::getdata "mount" "lastcorrectiondalpha"] * cos($delta)}]
        set deltaoffset [client::getdata "mount" "lastcorrectionddelta"]
        log::info [format "pointing error is %+.1fas E and %+.1fas N." [astrometry::radtoarcsec $alphaoffset] [astrometry::radtoarcsec $deltaoffset]]
        set totaloffset [expr {sqrt($alphaoffset * $alphaoffset + $deltaoffset * $deltaoffset)}]
        log::info [format "total pointing error is %.1fas." [astrometry::radtoarcsec $totaloffset]]
        if {$totaloffset < [server::getdata "pointingtolerance"]} {
          log::info "pointed to within tolerance."
        } else {
          client::request "mount" "preparetotrack"
          client::wait "mount"
          client::request "mount" "track"
          client::wait "mount"
        }
      }  
      foreach finder $finders {
        client::request $finder "stop"
      }
    }
    if {![string equal $guidingmode "none"]} {
      foreach finder $finders {
        client::wait $finder
      }
      client::wait "guider"
      client::request "guider" "guide $guidingmode"
    }
    client::wait "secondary"
    client::request "secondary" "move z0"
    client::wait "secondary"
    
    if {[string equal $pointingmode "map"]} {
      finders::expose 1 "astrometry"
    }

    variable lastalphaoffset
    variable lastdeltaoffset
    variable lastpointingaperture
    variable lastguidingmode
    set lastalphaoffset      $alphaoffset
    set lastdeltaoffset      $deltaoffset
    set lastpointingaperture $pointingaperture
    set lastguidingmode      $guidingmode

    log::info "finished moving."
    log::info "tracking."
  }
  
  proc ratiroffsetactivitycommand {alphaoffset deltaoffset} {

    variable finders
    variable lastalphaoffset
    variable lastdeltaoffset
    variable lastpointingaperture
    variable lastguidingmode

    log::info "offsetting."
    
    set guidingmode      [server::getdata "guidingmode"]
    set pointingaperture [server::getdata "pointingaperture"]

    if {
      [astrometry::parseangle $alphaoffset dms] == [astrometry::parseangle $lastalphaoffset dms] &&
      [astrometry::parseangle $deltaoffset dms] == [astrometry::parseangle $lastdeltaoffset dms] &&
      [string equal $pointingaperture $lastpointingaperture] &&
      [string equal $guidingmode $lastguidingmode]
    } {
      set offsetmount false
    } else {
      set offsetmount true
    }

    # We skip offsetting the mount if necessary. However, we always command the
    # dome to track, in order to reset the azimuth error statistics, and we also
    # always stop and start guiding, in order to allow the guider to switch
    # between finders.

    client::request "guider" "stop"
    foreach finder $finders {
      client::request $finder "stop"
    }

    client::request "dome" "preparetotrack"
    client::wait "dome"

    if {$offsetmount} {
      client::request "mount" "preparetotrack"
      client::wait "mount"
    }

    client::request "target" "offset $alphaoffset $deltaoffset $pointingaperture"
    client::wait "target"
    if {![client::getdata "target" "withinlimits"]} {
      log::warning "the target is not within the limits."
      client::request "mount" "stop"
      client::wait "mount"
      return
    }

    client::request "dome" "track"
    if {$offsetmount} {
      client::request "mount" "track"
      client::wait "mount"
    }
    client::request "secondary" "move z0"
    client::wait "dome"
    if {![string equal $guidingmode "none"]} {
      foreach finder $finders {
        client::wait $finder
      }
      client::wait "guider"
      client::request "guider" "guide $guidingmode"
    }
    client::wait "secondary"

    set lastalphaoffset      $alphaoffset
    set lastdeltaoffset      $deltaoffset
    set lastpointingaperture $pointingaperture
    set lastguidingmode      $guidingmode

    log::info "finished offsetting."
    log::info "tracking."
  }
  
  proc focusfindersactivitycommand {exposuretime range step} {
    log::info "focusing finders."
    variable finders
    client::request "guider" "stop"
    foreach finder $finders {
      client::request $finder "stop"
    }
    foreach finder $finders {
      client::wait $finder
    }
    foreach finder $finders {
      client::request $finder "focus $exposuretime $range $step"
    }
    foreach finder $finders {
      client::wait $finder
    }
    set guidingmode [server::getdata "guidingmode"]
    if {![string equal $guidingmode "none"]} {
      client::request "guider" "guide $guidingmode"
    }
    log::info "finished focusing finders."
  }
  
  proc correctactivitycommand {truemountalpha truemountdelta equinox} {
    log::info "correcting the pointing model."
    variable finders
    client::request "guider" "stop"
    client::wait "guider"
    finders::getfinderastrometry
    foreach finder $finders {
      client::wait $finder
    }
    foreach finder $finders {
      set alpha [client::getdata $finder "mountobservedalpha"]
      set delta [client::getdata $finder "mountobserveddelta"]
      if {[string equal $alpha "unknown"]} {
        log::warning "unable to correct pointing model."
        return
      }
    }
    if {[string equal $truemountalpha "unknown"] || [string equal $truemountdelta "unknown"]} {
      log::info "estimating the correction using the finders."
      set n 0
      set sumdalpha 0.0
      set sumddelta 0.0
      set firstalpha ""
      set firstdelta ""
      foreach finder $finders {
        set alpha [client::getdata $finder "mountobservedalpha"]
        set delta [client::getdata $finder "mountobserveddelta"]
        if {[string equal $alpha "unknown"]} {
          log::warning "unable to estimate the correction as $finder did not solve."
          return
        }
        set n [expr {$n + 1}]
        if {[string equal $firstalpha ""]} {
          set firstalpha $alpha
          set firstdelta $delta
        }
        set dalpha [astrometry::foldradsymmetric [expr {$alpha - $firstalpha}]]
        set ddelta [astrometry::foldradsymmetric [expr {$delta - $firstdelta}]]
        set sumdalpha [expr {$sumdalpha + $dalpha}]
        set sumddelta [expr {$sumddelta + $ddelta}]
      }
      set truemountalpha [astrometry::foldradpositive  [expr {$firstalpha + $sumdalpha / $n}]]
      set truemountdelta [astrometry::foldradsymmetric [expr {$firstdelta + $sumddelta / $n}]]
      set truemountalpha [astrometry::radtohms $truemountalpha 2 false]
      set truemountdelta [astrometry::radtodms $truemountdelta 1 true]
      set equinox "observed"
    }
    client::request "mount" "correct $truemountalpha $truemountdelta $equinox"
    foreach finder $finders {
      client::request $finder "correct $truemountalpha $truemountdelta $equinox"
    }
    log::info "finished correcting the pointing model."
  }
  
  ######################################################################
  
  proc checkvalue {component key value message} {
    if {![string equal [client::getdata $component "$key"] $value]} {
      error $message
    }
  }
  
  proc checkcomponent {component} {
    variable components
    if {![string equal "telescope" $component ] && [lsearch -exact $components $component] == -1} {
      error "invalid component \"$component\"."
    }
  }
  
  proc checklights {state} {
    checkvalue power dome-lights   $state "the dome lights are not $state."
  }

  proc startup {} {
    server::newactivitycommand "starting" "started" \
      "telescope::startactivitycommand" 1200000
  }
  
  proc shutdown {} {
    server::checkstatus    
    server::newactivitycommand "shuttingdown" "idle" \
      "telescope::shutdownactivitycommand"
  }
  
  proc switchlightson {} {
    server::checkstatus
    server::checkactivityforswitch
    server::newactivitycommand "switchingon" [server::getactivity] \
      "telescope::switchlightsonactivitycommand"
  }
  
  proc switchlightsoff {} {
    server::checkstatus
    server::checkactivityforswitch
    server::newactivitycommand "switchingoff" [server::getactivity] \
      "telescope::switchlightsoffactivitycommand"
  }
  
  proc ratiroffset {alphaoffset deltaoffset} {
    server::checkstatus
    server::checkactivity "tracking"
    astrometry::parseangle $alphaoffset dms
    astrometry::parseangle $deltaoffset dms
    server::newactivitycommand "moving" "tracking" \
      "telescope::ratiroffsetactivitycommand $alphaoffset $deltaoffset"
  }
  
  proc guide {alphaoffset deltaoffset} {
    server::checkstatus
    server::checkactivity "tracking"
    set alphaoffset [astrometry::radtoarcsec [astrometry::parseangle $alphaoffset dms]]
    set deltaoffset [astrometry::radtoarcsec [astrometry::parseangle $deltaoffset dms]]
    client::request "mount" [format "guide %+.2fas %+.2fas" $alphaoffset $deltaoffset]
  }
  
  proc focusfinders {exposuretime range step} {
    server::checkstatus
    server::checkactivity "tracking"
    server::newactivitycommand "focusing" "tracking" \
      "telescope::focusfindersactivitycommand $exposuretime $range $step" false
  }
  
  proc setpointingmode {mode} {
    server::checkstatus
    if {
      ![string equal $mode "none"] &&
      ![string equal $mode "finder"] &&
      ![string equal $mode "map"]
    } {
      error "invalid pointing mode \"$mode\"."
    }
    log::info "setting pointing mode to \"$mode\"."
    server::setdata "pointingmode" $mode
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info "finished setting pointing mode."
    return
  }
  
  proc setpointingtolerance {tolerance} {
    server::checkstatus
    log::info "setting pointing tolerance to \"$tolerance\"."
    server::setdata "pointingtolerance" [astrometry::parseangle $tolerance dms]
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info "finished setting pointing tolerance."
    return
  }
  
  proc setpointingaperture {aperture} {
    server::checkstatus
    pointing::checkaperture $aperture
    log::info "setting pointing aperture to \"$aperture\"."
    server::setdata "pointingaperture" $aperture
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info "finished setting pointing aperture."
    return
  }
  
  proc setguidingmode {mode} {
    server::checkstatus
    if {
      ![string equal $mode "none"] &&
      ![string equal $mode "finder"] &&
      ![string equal $mode "C0"] &&
      ![string equal $mode "C1"] &&
      ![string equal $mode "C0donuts"] &&
      ![string equal $mode "C1donuts"]
    } {
      error "invalid guiding mode \"$mode\"."
    }
    log::info "setting guiding mode to \"$mode\"."
    server::setdata "guidingmode" $mode
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info "finished setting guiding mode."
    return
  }
  
  proc correct {truemountalpha truemountdelta equinox} {
    server::checkstatus
    server::checkactivity "tracking"
    server::newactivitycommand "correcting" "tracking" \
      "telescope::correctactivitycommand $truemountalpha $truemountdelta $equinox"
  }
  
  ######################################################################
  ######################################################################
  
  proc startupcoversactivitycommand {{type info} {wait false}} {
    log::$type "starting up the covers (and the inclinometers)."
    shutdowncoversactivitycommand
    switchoncoversactivitycommand
    startserver "covers"
    startserver "inclinometers"
    if {$wait} {
      client::waituntilstarted "covers"
      client::waituntilstarted "inclinometers"
    }   
    log::$type "finished starting up the covers (and the inclinometers)."
  }
  
  proc shutdowncoversactivitycommand {{type info}} {
    log::$type "shutting down the covers (and the inclinometers)."
    stopserver "covers"
    stopserver "inclinometers"
    switchoffcoversactivitycommand
    log::$type "finished shutting down the covers (and the inclinometers)."
  }
  
  proc switchoncoversactivitycommand {{type info}} {
    log::$type "switching on the covers (and the inclinometers)."
    switchon "inclinometers/covers"
    log::$type "finished switching on the covers (and the inclinometers)."
  }
  
  proc switchoffcoversactivitycommand {{type info}} {
    log::$type "switching off the covers (and the inclinometers)."
    switchoff "inclinometers/covers"
    log::$type "finished switching off the covers (and the inclinometers)."
  }
  
  proc resetcoversactivitycommand {{type info}} {
    log::$type "resetting the covers."
    client::request "covers" "reset"
    log::$type "finished resetting the covers."
  }
  
  proc initializecoversactivitycommand {{type info}} {
    log::$type "initializing the covers."
    client::waituntilstarted "covers"
    client::request "covers" "stop"
    client::wait "covers"
    client::request "inclinometers" "suspend"
    client::wait "inclinometers"
    client::request "covers" "initialize"
    client::wait "covers"
    client::request "inclinometers" "resume"
    client::wait "inclinometers"
    log::$type "finished initializing the covers."
  }
  
  proc stopcoversactivitycommand {{type info}} {
    log::$type "stopping the covers."
    client::request "covers" "stop"
    log::$type "finished stopping the covers."
  }
  
  proc opencoversactivitycommand {{type info}} {
    log::$type "opening the covers."
    client::request "inclinometers" "suspend"
    client::wait "inclinometers"
    client::request "covers" "open"
    client::wait "covers"
    client::request "inclinometers" "resume"
    client::wait "inclinometers"
    log::$type "finished opening the covers."
  }
  
  proc closecoversactivitycommand {{type info}} {
    log::$type "closing the covers."
    client::request "inclinometers" "suspend"
    client::wait "inclinometers"
    client::request "covers" "close"
    client::wait "covers"
    client::request "inclinometers" "resume"
    client::wait "inclinometers"
    log::$type "finished closing the covers."
  }
  
  ######################################################################
  ######################################################################

  proc startupdomeactivitycommand {{type info} {wait false}} {
    log::$type "starting up the dome."
    shutdowndomeactivitycommand
    switchondomeactivitycommand
    startserver "dome"
    if {$wait} {
      client::waituntilstarted "dome"
    }
    log::$type "finished starting up the dome."
  }
  
  proc shutdowndomeactivitycommand {{type info}} {
    log::$type "shutting down the dome."
    stopserver "dome"
    switchoffdomeactivitycommand
    log::$type "finished shutting down the dome."
  }
  
  proc switchondomeactivitycommand {{type info}} {
    log::$type "switching on the dome."
    switchon "dome"
    log::$type "finished switching on the dome."
  }
  
  proc switchoffdomeactivitycommand {{type info}} {
    log::$type "switching off the dome."
    switchoff "dome"
    log::$type "finished switching off the dome."
  }
  
  proc resetdomeactivitycommand {{type info}} {
    log::$type "resetting the dome."
    client::request "dome" "reset"
    log::$type "finished resetting the dome."
  }
  
  proc initializedomeactivitycommand {{type info}} {
    log::$type "initializing the dome."
    client::waituntilstarted "dome"
    client::request "dome" "stop"
    client::wait "dome"
    client::request "dome" "initialize"
    client::wait "dome"
    log::$type "finished initializing the dome."
  }
  
  proc stopdomeactivitycommand {{type info}} {
    log::$type "stopping the dome."
    client::request "dome" "stop"
    log::$type "finished stopping the dome."
  }
  
  proc movedomeactivitycommand {azimuth {type info}} {
    log::$type "moving the dome to $azimuth."
    client::request "dome" "preparetomove"
    client::wait "dome"
    client::request "dome" "move $azimuth"
    client::wait "dome"
    log::$type "finished moving the dome."
  }
  
  ######################################################################
  ######################################################################
    
  proc startupguideractivitycommand {{type info} {wait false}} {
    log::$type "starting up the guider."
    stopserver "guider"
    startserver "guider"
    if {$wait} {
      client::waituntilstarted "guider"
    }
    log::$type "finished starting up the guider."
  }
  
  proc shutdownguideractivitycommand {{type info}} {
    log::$type "shutting down the guider."
    stopserver "guider"
    log::$type "finished shutting down the guider."
  }
  
  proc resetguideractivitycommand {{type info}} {
    log::$type "resetting the guider."
    client::request "guider" "reset"
    log::$type "finished resetting the guider."
  }
  
  ######################################################################
  ######################################################################
  
  proc startuppoweractivitycommand {{type info} {wait false}} {
    log::$type "starting up the power."
    stopserver "power"
    startserver "power"
    if {$wait} {
      client::waituntilstarted "power"
    }
    log::$type "finished starting up the power."
  }
  
  proc shutdownpoweractivitycommand {{type info}} {
    log::$type "shutting down the power."
    stopserver "power"
    log::$type "finished shutting down the power."
  }
  
  proc resetpoweractivitycommand {{type info}} {
    log::$type "resetting the power."
    client::request "power" "reset"
    log::$type "finished resetting the power."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupinclinometersactivitycommand {{type info} {wait false}} {
    log::$type "starting up the inclinometers (and the covers)."
    shutdowninclinometersactivitycommand
    switchoninclinometersactivitycommand
    startserver "covers"
    startserver "inclinometers"
    if {$wait} {
      client::waituntilstarted "covers"
      client::waituntilstarted "inclinometers"
    }
    log::$type "finished starting up the inclinometers (and the covers)."
  }
  
  proc shutdowninclinometersactivitycommand {{type info}} {
    log::$type "shutting down the inclinometers (and the covers)."
    stopserver "inclinometers"
    stopserver "inclinometers"
    switchoffinclinometersactivitycommand
    log::$type "finished shutting down the inclinometers (and the covers)."
  }
  
  proc switchoninclinometersactivitycommand {{type info}} {
    log::$type "switching on the inclinometers (and the covers)."
    switchon "inclinometers/covers"
    log::$type "finished switching on the inclinometers (and the covers)."
  }
  
  proc switchoffinclinometersactivitycommand {{type info}} {
    log::$type "switching off the inclinometers (and the covers)."
    switchoff "inclinometers/covers"
    log::$type "finished switching off the inclinometers (and the covers)."
  }

  proc resetinclinometersactivitycommand {{type info}} {
    log::$type "resetting the inclinometers."
    client::request "inclinometers" "reset"
    log::$type "finished resetting the inclinometers."
  }
  
  ######################################################################
  ######################################################################
    
  proc startuptelescopeactivitycommand {{type info} {wait false}} {
    log::$type "starting up the telescope."
    log::$type "finished starting up the telescope."
  }

  proc shutdowntelescopeactivitycommand {{type info}} {
    log::$type "shutting down the telescope."
    stopserver "telescope"
    log::$type "finished shutting down the telescope."
  }
  
  proc resettelescopeactivitycommand {{type info}} {
    log::$type "resetting the telescope."
    client::request "telescope" "reset"
    log::$type "finished resetting the telescope."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupmoonactivitycommand {{type info} {wait false}} {
    log::$type "starting up the moon."
    stopserver "moon"
    startserver "moon"
    if {$wait} {
      client::waituntilstarted "moon"
    }
    log::$type "finished starting up the moon."
  }
  
  proc shutdownmoonactivitycommand {{type info}} {
    log::$type "shutting down the moon."
    stopserver "moon"
    log::$type "finished shutting down the moon."
  }
  
  proc resetmoonactivitycommand {{type info}} {
    log::$type "resetting the moon."
    client::request "moon" "reset"
    log::$type "finished resetting the moon."
  }
  
  ######################################################################
  ######################################################################

  proc startupmountactivitycommand {{type info} {wait false}} {
    log::$type "starting up the mount."
    stopserver "mount"
    shutdownmountactivitycommand
    switchonmountactivitycommand
    coroutine::after 20000
    startserver "mount"
    if {$wait} {
      client::waituntilstarted "mount"
    }
    log::$type "finished starting up the mount."
  }
  
  proc shutdownmountactivitycommand {{type info}} {
    log::$type "shutting down the mount."
    stopserver "mount"
    switchoffmountactivitycommand
    log::$type "finished shutting down the mount."
  }
  
  proc switchonmountactivitycommand {{type info}} {
    log::$type "switching on the mount hardware (except the mount motors)."
    switchon "mount"
    switchon "mount-adapter"
    log::$type "finished switching on the mount hardware (except the mount motors)."
  }
  
  proc switchoffmountactivitycommand {{type info}} {
    log::$type "switching off the mount."
    switchoff "mount-motors"
    switchoff "mount-adapter"
    switchoff "mount"
    log::$type "finished switching off the mount."
  }
  
  proc resetmountactivitycommand {{type info}} {
    log::$type "resetting the mount."
    client::request "mount" "reset"
    log::$type "finished resetting the mount."
  }
  
  proc initializemountactivitycommand {{type info}} {
    log::$type "initializing the mount."
    client::waituntilstarted "mount"
    log::info "switching on the mount motors."
    switchon "mount-motors"
    log::info "finished switching on the mount motors."
    client::request "target" "movetoidle"
    client::request "mount" "initialize"
    client::wait "mount"
    log::$type "finished initializing the mount."
  }
  
  proc stopmountactivitycommand {{type info}} {
    log::$type "stopping the mount."
    client::request "mount" "stop"
    log::$type "finished stopping the mount."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupnefinderactivitycommand {{type info} {wait false}} {
    log::$type "starting up the nefinder."
    shutdownnefinderactivitycommand
    switchonnefinderactivitycommand
    startserver "nefinder"
    if {$wait} {
      client::waituntilstarted "nefinder"
    }
    log::$type "finished starting up the nefinder."
  }
  
  proc shutdownnefinderactivitycommand {{type info}} {
    log::$type "shutting down the nefinder."
    stopserver "nefinder"
    switchoffnefinderactivitycommand
    log::$type "finished shutting down the nefinder."
  }
  
  proc switchonnefinderactivitycommand {{type info}} {
    log::$type "switching on the nefinder."
    switchon "nefinder-ccd"
    switchon "nefinder-focuser"
    log::$type "finished switching on the nefinder."
  }
  
  proc switchoffnefinderactivitycommand {{type info}} {
    log::$type "switching off the nefinder."
    switchoff "nefinder-ccd"
    switchoff "nefinder-focuser"
    log::$type "finished switching off the nefinder."
  }
  
  proc resetnefinderactivitycommand {{type info}} {
    log::$type "resetting the nefinder."
    client::request "nefinder" "reset"
    log::$type "finished resetting the nefinder."
  }
  
  proc initializenefinderactivitycommand {{type info}} {
    log::$type "initializing the nefinder."
    client::waituntilstarted "nefinder"
    client::request "nefinder" "initialize"
    client::wait "nefinder"
    log::$type "finished initializing the nefinder."
  }
  
  proc stopnefinderactivitycommand {{type info}} {
    log::$type "stopping the nefinder."
    client::request "nefinder" "stop"
    log::$type "finished stopping the nefinder."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupowsensorsactivitycommand {{type info} {wait false}} {
    log::$type "starting up the owsensors."
    stopserver "owsensors"
    startserver "owsensors"
    if {$wait} {
      client::waituntilstarted "owsensors"
    }
    log::$type "finished starting up the owsensors."
  }
  
  proc shutdownowsensorsactivitycommand {{type info}} {
    log::$type "shutting down the owsensors."
    stopserver "owsensors"
    log::$type "finished shutting down the owsensors."
  }
  
  proc resetowsensorsactivitycommand {{type info}} {
    log::$type "resetting the owsensors."
    client::request "owsensors" "reset"
    log::$type "finished resetting the owsensors."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupsefinderactivitycommand {{type info} {wait false}} {
    log::$type "starting up the sefinder."
    shutdownsefinderactivitycommand
    switchonsefinderactivitycommand
    startserver "sefinder"
    if {$wait} {
      client::waituntilstarted "sefinder"
    }
    log::$type "finished starting up the sefinder."
  }
  
  proc shutdownsefinderactivitycommand {{type info}} {
    log::$type "shutting down the sefinder."
    stopserver "sefinder"
    switchoffsefinderactivitycommand
    log::$type "finished shutting down the sefinder."
  }
  
  proc switchonsefinderactivitycommand {{type info}} {
    log::$type "switching on the sefinder."
    switchon "sefinder-ccd"
    switchon "sefinder-focuser"
    log::$type "finished switching on the sefinder."
  }
  
  proc switchoffsefinderactivitycommand {{type info}} {
    log::$type "switching off the sefinder."
    switchoff "sefinder-ccd"
    switchoff "sefinder-focuser"
    log::$type "finished switching off the sefinder."
  }
  
  proc resetsefinderactivitycommand {{type info}} {
    log::$type "resetting the sefinder."
    client::request "sefinder" "reset"
    log::$type "finished resetting the sefinder."
  }
  
  proc initializesefinderactivitycommand {{type info}} {
    log::$type "initializing the sefinder."
    client::waituntilstarted "sefinder"
    client::request "sefinder" "initialize"
    client::wait "sefinder"
    log::$type "finished initializing the sefinder."
  }
  
  proc stopsefinderactivitycommand {{type info}} {
    log::$type "stopping the sefinder."
    client::request "sefinder" "stop"
    log::$type "finished stopping the sefinder."
  }
  
  ######################################################################
  ######################################################################

  proc startupsecondaryactivitycommand {{type info} {wait false}} {
    log::$type "starting up the secondary."
    shutdownsecondaryactivitycommand
    switchonsecondaryactivitycommand
    startserver "secondary"
    if {$wait} {
      client::waituntilstarted "secondary"
    }
    log::$type "finished starting up the secondary."
  }
  
  proc shutdownsecondaryactivitycommand {{type info}} {
    log::$type "shutting down the secondary."
    stopserver "secondary"
    switchoffsecondaryactivitycommand
    log::$type "finished shutting down the secondary."
  }
  
  proc switchonsecondaryactivitycommand {{type info}} {
    log::$type "switching on the secondary."
    switchon "secondary"
    log::$type "finished switching on the secondary."
  }
  
  proc switchoffsecondaryactivitycommand {{type info}} {
    log::$type "switching off the secondary."
    switchoff "secondary"
    log::$type "finished switching off the secondary."
  }
  
  proc resetsecondaryactivitycommand {{type info}} {
    log::$type "resetting the secondary."
    client::request "secondary" "reset"
    log::$type "finished resetting the secondary."
  }
  
  proc initializesecondaryactivitycommand {{type info}} {
    log::$type "initializing the secondary."
    client::waituntilstarted "secondary"
    client::request "secondary" "stop"
    client::wait "secondary"
    client::request "secondary" "initialize"
    client::wait "secondary"
    log::$type "finished initializing the secondary."
  }
  
  proc stopsecondaryactivitycommand {{type info}} {
    log::$type "stopping the secondary."
    client::request "secondary" "stop"
    log::$type "finished stopping the secondary."
  }
  
  ######################################################################
  
  proc startupshuttersactivitycommand {{type info} {wait false}} {
    log::$type "starting up the shutters."
    shutdownshuttersactivitycommand
    switchonshuttersactivitycommand
    startserver "shutters"
    if {$wait} {
      client::waituntilstarted "shutters"
    }
    log::$type "finished starting up the shutters."
  }
  
  proc shutdownshuttersactivitycommand {{type info}} {
    log::$type "shutting down the shutters."
    stopserver "shutters"
    switchoffshuttersactivitycommand
    log::$type "finished shutting down the shutters."
  }
  
  proc switchonshuttersactivitycommand {{type info}} {
    log::$type "switching on the shutters."
    switchon "shutters"
    log::$type "finished switching on the shutters."
  }
  
  proc switchoffshuttersactivitycommand {{type info}} {
    log::$type "switching off the shutters."
    switchoff "shutters"
    log::$type "finished switching off the shutters."
  }
  
  proc resetshuttersactivitycommand {{type info}} {
    log::$type "resetting the shutters."
    client::request "shutters" "reset"
    log::$type "finished resetting the shutters."
  }
  
  proc initializeshuttersactivitycommand {{type info}} {
    log::$type "initializing the shutters."
    client::waituntilstarted "shutters"
    movedometocontacts
    log::info "initializing the shutters."
    client::request "shutters" "stop"
    client::wait "shutters"
    client::request "shutters" "initialize"
    client::wait "shutters"
    log::$type "finished initializing the shutters."
  }
  
  proc stopshuttersactivitycommand {{type info}} {
    log::$type "stopping the shutters."
    client::request "shutters" "stop"
    log::$type "finished stopping the shutters."
  }
  
  proc openshuttersactivitycommand {{type info}} {
    log::$type "opening the shutters."
    movedometocontacts
    log::info "opening the shutters."
    client::request "shutters" "open"
    client::wait "shutters"
    log::$type "finished opening the shutters."
  }
  
  proc closeshuttersactivitycommand {{type info}} {
    log::$type "closing the shutters."
    movedometocontacts
    log::info "closing the shutters."
    client::request "shutters" "close"
    client::wait "shutters"
    log::$type "finished closing the shutters."
  }

  proc movedometocontacts {} {
    movedomeactivitycommand "contacts"
    set i 0
    while {![string equal [getpowercontacts] "closed"] && $i < 4} {
      log::warning "reinitializing the dome as the shutters power contacts did not close."
      initializedomeactivitycommand
      movedomeactivitycommand "contacts"
      incr i
    }
    if {![string equal [getpowercontacts] "closed"]} {
      error "unable to close the shutters power contacts."
    }
  }

  ######################################################################
  ######################################################################
  
  proc startupsunactivitycommand {{type info} {wait false}} {
    log::$type "starting up the sun."
    stopserver "sun"
    startserver "sun"
    if {$wait} {
      client::waituntilstarted "sun"
    }
    log::$type "finished starting up the sun."
  }
  
  proc shutdownsunactivitycommand {{type info}} {
    log::$type "shutting down the sun."
    stopserver "sun"
    log::$type "finished shutting down the sun."
  }
  
  proc resetsunactivitycommand {{type info}} {
    log::$type "resetting the sun."
    client::request "sun" "reset"
    log::$type "finished resetting the sun."
  }
  
  ######################################################################
  ######################################################################
  
  proc startuptargetactivitycommand {{type info} {wait false}} {
    log::$type "starting up the target."
    stopserver "target"
    startserver "target"
    if {$wait} {
      client::waituntilstarted "target"
    }
    log::$type "finished starting up the target."
  }
  
  proc shutdowntargetactivitycommand {{type info}} {
    log::$type "shutting down the target."
    stopserver "target"
    log::$type "finished shutting down the target."
  }
  
  proc resettargetactivitycommand {{type info}} {
    log::$type "resetting the target."
    client::request "target" "reset"
    log::$type "finished resetting the target."
  }
  
  ######################################################################
  ######################################################################
  
  proc startupweatheractivitycommand {{type info} {wait false}} {
    log::$type "starting up the weather."
    stopserver "weather"
    startserver "weather"
    if {$wait} {
      client::waituntilstarted "weather"
    }
    log::$type "finished starting up the weather."
  }
  
  proc shutdownweatheractivitycommand {{type info}} {
    log::$type "shutting down the weather."
    stopserver "weather"
    log::$type "finished shutting down the weather."
  }
  
  proc resetweatheractivitycommand {{type info}} {
    log::$type "resetting the weather."
    client::request "weather" "reset"
    log::$type "finished resetting the weather."
  }
  
  ######################################################################

  ######################################################################

  proc setpointingmode {mode} {
    server::checkstatus
    if {
      ![string equal $mode "none"] &&
      ![string equal $mode "map"]
    } {
      error "invalid pointing mode \"$mode\"."
    }
    set start [utcclock::seconds]
    log::info "setting pointing mode to \"$mode\"."
    server::setdata "pointingmode" $mode
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info [format "finished setting pointing aperture after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc setpointingtolerance {tolerance} {
    server::checkstatus
    set start [utcclock::seconds]
    log::info "setting pointing tolerance to $tolerance."
    server::setdata "pointingtolerance" [astrometry::parseangle $tolerance dms]
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info [format "finished setting pointing tolerance after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc setguidingmode {mode} {
    server::checkstatus
    if {
      ![string equal $mode "none"]
    } {
      error "invalid guiding mode $mode."
    }
    set start [utcclock::seconds]
    log::info "setting guiding mode to \"$mode\"."
    server::setdata "guidingmode" $mode
    server::setdata "timestamp" [utcclock::combinedformat now]
    log::info [format "finished setting guiding mode after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc track {alpha delta equinox alphaoffset deltaoffset {epoch "now"} {alpharate 0} {deltarate 0} {aperture "default"}} {
    server::checkstatus
    server::checkactivity "moving" "idle" "tracking"
    astrometry::parsealpha   $alpha
    astrometry::parsedelta   $delta
    astrometry::parseequinox $equinox
    astrometry::parseoffset  $alphaoffset
    astrometry::parseoffset  $deltaoffset
    astrometry::parseepoch   $epoch
    astrometry::parserate    $alpharate
    astrometry::parserate    $deltarate
    pointing::checkaperture $aperture
    server::newactivitycommand "moving" "tracking" \
      "telescope::trackactivitycommand $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $aperture"
  }
  
  proc trackcatalogobject {catalogname objectname aperture} {
    variable catalogdirectory
    set channel [::open "|getcatalogobject -d \"$catalogdirectory\" -- \"$catalogname\" \"$objectname\"" "r"]
    set line [coroutine::gets $channel]
    catch {::close $channel}
    if {[string equal $line ""]} {
      error "object \"$objectname\" not found in catalog \"$catalogname\"."
    }
    eval track $line 0 0 now 0 0 $aperture
  }
  
  proc tracktopocentric {ha delta aperture} {
    set ha    [astrometry::parseha $ha]
    set alpha [astrometry::formatalpha [astrometry::alpha $ha]]
    set delta [astrometry::formatdelta [astrometry::parsedelta $delta]]
    track $alpha $delta now 0 0 now 0 0 $aperture  
  }
  
  proc offset {alphaoffset deltaoffset aperture} {
    server::checkstatus
    server::checkactivity "tracking"
    astrometry::parseoffset $alphaoffset
    astrometry::parseoffset $deltaoffset
    pointing::checkaperture $aperture
    server::newactivitycommand "moving" "tracking" \
      "telescope::offsetactivitycommand $alphaoffset $deltaoffset $aperture"
  }
  
  proc correct {truemountalpha truemountdelta equinox} {
    server::checkstatus
    set start [utcclock::seconds]
    log::info "correcting the pointing model."
    astrometry::parsealpha $truemountalpha
    astrometry::parsedelta $truemountdelta
    astrometry::parseequinox $equinox
    log::info "correcting the pointing model."
    client::request "mount" "correct $truemountalpha $truemountdelta $equinox"
    log::info [format "finished correcting the pointing model after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc reset {} {
    server::checkstatus
    server::checkactivitynot "starting"
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "telescope::resetactivitycommand" 1200e3
  }
  
  proc stop {} {
    server::checkstatus
    server::checkactivitynot "starting" "error"
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "telescope::stopactivitycommand"
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivitynot "starting" "error"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "initializing" "idle" \
      "telescope::initializeactivitycommand" 1200e3
  }
  
  proc open {} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "opening" "idle" \
      "telescope::openactivitycommand" 1200e3
  }
  
  proc opentocool {} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "opening" "idle" \
      "telescope::opentocoolactivitycommand" 1200e3
  }
  
  proc close {} {
    server::checkstatus
    server::checkactivity "stopping" "moving" "tracking" "focusing" "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "closing" "idle" \
     telescope::closeactivitycommand 1200e3
  }
  
  proc emergencyclose {} {
    # Do not check status or activity.
    safetyswitch::checksafetyswitch
    server::newactivitycommand "closing" [server::getstoppedactivity] \
      telescope::emergencycloseactivitycommand 1200e3
  }
  
  proc move {ha delta} {
    server::checkstatus
    server::checkactivity "moving" "tracking" "idle"
    safetyswitch::checksafetyswitch
    astrometry::parseha $ha
    astrometry::parsedelta $delta
    server::newactivitycommand "moving" "idle" \
      "telescope::moveactivitycommand $ha $delta"
  }
  
  proc movetoidle {} {
    log::info "moving to zenith."
    move 0h [format "%.4fd" [astrometry::radtodeg [astrometry::latitude]]]
  }
  
  proc park {} {
    server::checkstatus
    server::checkactivity "moving" "tracking" "idle"
    safetyswitch::checksafetyswitch
    log::info "parking"
    server::newactivitycommand "parking" "idle" \
      "telescope::parkactivitycommand"
  }
  
  proc unpark {} {
    server::checkstatus
    server::checkactivity "moving" "tracking" "idle"
    safetyswitch::checksafetyswitch
    log::info "unparking"
    server::newactivitycommand "unparking" "idle" \
      "telescope::unparkactivitycommand"
  }
  
  proc ratirtrack {alpha delta equinox {alphaoffset 0} {deltaoffset 0} {epoch now} {alpharate 0} {deltarate 0}} {
    server::checkstatus
    server::checkactivity "moving" "tracking" "idle"
    safetyswitch::checksafetyswitch
    astrometry::parsealpha   $alpha
    astrometry::parsedelta   $delta
    astrometry::parseequinox $equinox
    astrometry::parseoffset  $alphaoffset
    astrometry::parseoffset  $deltaoffset
    astrometry::parserate    $alpharate
    astrometry::parserate    $deltarate
    server::newactivitycommand "moving" "tracking" \
      "telescope::ratirtrackactivitycommand $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate"
  }
  
  proc ratirtrackcatalogobject {catalogname objectname} {
    variable catalogdirectory
    set channel [::open "|getcatalogobject -d \"$catalogdirectory\" -- \"$catalogname\" \"$objectname\"" "r"]
    set line [coroutine::gets $channel]
    catch {::close $channel}
    if {[string equal $line ""]} {
      error "object \"$objectname\" not found in catalog \"$catalogname\"."
    }
    eval ratirtrack $line
  }
  
  proc ratirtracktopocentric {ha delta} {
    set ha    [astrometry::parseha $ha]
    set delta [astrometry::parsedelta $delta]
    set alpha [astrometry::alpha $ha]
    ratirtrack [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] now    
  }
  
  proc map {ha delta exposuretime} {
    set ha    [astrometry::parseha $ha]
    set delta [astrometry::parsedelta $delta]
    set alpha [astrometry::foldradpositive [expr {[astrometry::last] - $ha}]]
    server::newactivitycommand "mapping" "idle" \
      "telescope::mapactivitycommand $alpha $delta $exposuretime"
  }
  
  proc movesecondary {z0 setasinitial} {
    variable withsecondary
    if {!$withsecondary} {
      error "the telescope does not have a secondary."
    }
    server::checkstatus
    server::checkactivity "idle" "tracking"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "moving" [server::getactivity] \
      "telescope::movesecondaryactivitycommand $z0 $setasinitial"
  }

  proc setsecondaryoffset {dz} {
    variable withsecondary
    if {!$withsecondary} {
      error "the telescope does not have a secondary."
    }
    server::checkstatus
    server::checkactivity "idle" "tracking"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "setting" [server::getactivity] \
      "telescope::setsecondaryoffsetactivitycommand $dz"
  }

  ######################################################################

  set server::datalifeseconds 0

  ######################################################################

  proc start {} {
    server::setstatus "ok"
    server::newactivitycommand "starting" "started" \
      telescope::startactivitycommand 1200000
  }

}
