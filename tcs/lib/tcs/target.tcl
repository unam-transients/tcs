########################################################################

# This file is part of the UNAM telescope control system.

# $Id: target.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2010, 2011, 2012, 2013, 2014, 2015, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "pointing"
package require "coroutine"
package require "server"
package require "utcclock"

package provide "target" 0.0


namespace eval "target" {

  variable svnid {$Id}

  ######################################################################

  variable easthalimit            [astrometry::parseangle [config::getvalue "target" "easthalimit"]     "hms"]
  variable westhalimit            [astrometry::parseangle [config::getvalue "target" "westhalimit"]     "hms"]
  variable northdeltalimit        [astrometry::parseangle [config::getvalue "target" "northdeltalimit"] "dms"]
  variable southdeltalimit        [astrometry::parseangle [config::getvalue "target" "southdeltalimit"] "dms"]
  variable minzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "minzenithdistancelimit"]]
  variable maxzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "maxzenithdistancelimit"]]
  
  variable idleha    [astrometry::parseha    [config::getvalue "target" "idleha"   ]]
  variable idledelta [astrometry::parsedelta [config::getvalue "target" "idledelta"]]

  ######################################################################

  proc setrequestedposition {
    requestedha requestedalpha requesteddelta requestedequinox
    requestedalphaoffset requesteddeltaoffset
    requestedepochtimestamp requestedalpharate requesteddeltarate
    requestedaperture
  } {
    server::setdata "requestedha"             $requestedha
    server::setdata "requestedalpha"          $requestedalpha
    server::setdata "requesteddelta"          $requesteddelta
    server::setdata "requestedequinox"        $requestedequinox
    server::setdata "requestedalphaoffset"    $requestedalphaoffset
    server::setdata "requesteddeltaoffset"    $requesteddeltaoffset
    server::setdata "requestedepochtimestamp" $requestedepochtimestamp
    server::setdata "requestedalpharate"      $requestedalpharate
    server::setdata "requesteddeltarate"      $requesteddeltarate
    server::setdata "requestedaperture"       $requestedaperture
    server::setdata "withinlimits"            true
    updateobservedposition
    if {[string equal [server::getdata "requestedequinox"] ""]} {
      log::info [format "requested fixed position is %s %s." \
        [astrometry::radtohms [server::getdata "requestedha"] 2 true] \
        [astrometry::radtodms [server::getdata "requesteddelta"] 1 true]]
    } else {
      log::info [format "requested tracking position is %s %s %.2f." \
        [astrometry::radtohms [server::getdata "requestedalpha"] 2 false] \
        [astrometry::radtodms [server::getdata "requesteddelta"] 1 true] \
        [server::getdata "requestedequinox"]]
      log::info [format "requested HA is %s." \
        [astrometry::radtohms [server::getdata "observedha"] 2 true]]
      log::info [format "observed airmass is %.3f." \
        [server::getdata "observedairmass"]]
    }
  }
  
  proc setrequestedpositiontoidle {} {
    variable idleha
    variable idledelta
    setrequestedposition \
      $idleha "" $idledelta "" \
      "" "" \
      "" "" "" \
      "default"
  }  

  proc updateobservedposition {} {

    set seconds [utcclock::seconds]

    set requestedha             [server::getdata "requestedha"]
    set requestedalpha          [server::getdata "requestedalpha"]
    set requesteddelta          [server::getdata "requesteddelta"]
    set requestedequinox        [server::getdata "requestedequinox"]
    set requestedalphaoffset    [server::getdata "requestedalphaoffset"]
    set requesteddeltaoffset    [server::getdata "requesteddeltaoffset"]
    set requestedepochtimestamp [server::getdata "requestedepochtimestamp"]
    set requestedalpharate      [server::getdata "requestedalpharate"]
    set requesteddeltarate      [server::getdata "requesteddeltarate"]
    set requestedaperture       [server::getdata "requestedaperture"]
    
    if {[string equal [server::getrequestedactivity] "tracking"]} {

      set dseconds 60.0
      set epochseconds  [utcclock::scan $requestedepochtimestamp]
      set futureseconds [expr {$seconds + $dseconds}]
      
      set aperturealphaoffset [pointing::getaperturealphaoffset $requestedaperture]
      set aperturedeltaoffset [pointing::getaperturedeltaoffset $requestedaperture]      

      set currentdelta   [expr {
        $requesteddelta + ($requesteddeltaoffset + ($seconds - $epochseconds) * $requesteddeltarate)
      }]
      set currentalpha   [astrometry::foldradpositive [expr {
        $requestedalpha + ($requestedalphaoffset + ($seconds - $epochseconds) * $requestedalpharate) / cos($currentdelta)
      }]]
      set currentha      ""
      set currentequinox $requestedequinox

      set futurecurrentdelta [expr {
        $requesteddelta + ($requesteddeltaoffset + ($futureseconds - $epochseconds) * $requesteddeltarate)
      }]
      set futurecurrentalpha [astrometry::foldradpositive [expr {
        $requestedalpha + ($requestedalphaoffset + ($futureseconds - $epochseconds) * $requestedalpharate) / cos($futurecurrentdelta)
      }]]

      set standardequinox 2000.0

      set standardalpha [astrometry::precessedalpha $currentalpha $currentdelta $currentequinox $standardequinox]
      set standarddelta [astrometry::precesseddelta $currentalpha $currentdelta $currentequinox $standardequinox]

      set futurestandardalpha [astrometry::precessedalpha $futurecurrentalpha $futurecurrentdelta $currentequinox $standardequinox]
      set futurestandarddelta [astrometry::precesseddelta $futurecurrentalpha $futurecurrentdelta $currentequinox $standardequinox]

      set standardalpharate [astrometry::foldradsymmetric [expr {
        ($futurestandardalpha - $standardalpha) / $dseconds * cos($currentdelta)
      }]]
      set standarddeltarate [expr {
        ($futurestandarddelta - $standarddelta) / $dseconds
      }]

      set observedalpha [astrometry::observedalpha $currentalpha $currentdelta $currentequinox $seconds]
      set observeddelta [astrometry::observeddelta $currentalpha $currentdelta $currentequinox $seconds]
      set observedalpha [astrometry::foldradpositive [expr {$observedalpha + $aperturealphaoffset / cos($observeddelta)}]]
      set observeddelta [astrometry::foldradsymmetric [expr {$observeddelta + $aperturedeltaoffset}]]      
      set observedha    [astrometry::ha $observedalpha $seconds]

      set futureobservedalpha [astrometry::observedalpha $futurecurrentalpha $futurecurrentdelta $currentequinox $futureseconds]
      set futureobserveddelta [astrometry::observeddelta $futurecurrentalpha $futurecurrentdelta $currentequinox $futureseconds]
      set futureobservedalpha [astrometry::foldradpositive [expr {$futureobservedalpha + $aperturealphaoffset / cos($futureobserveddelta)}]]
      set futureobserveddelta [astrometry::foldradsymmetric [expr {$futureobserveddelta + $aperturedeltaoffset}]]      
      set futureobservedha    [astrometry::ha $futureobservedalpha $futureseconds]

      set observedalpharate [astrometry::foldradsymmetric [expr {
        ($futureobservedalpha - $observedalpha) / $dseconds * cos($currentdelta)
      }]]
      set observeddeltarate [expr {
        ($futureobserveddelta - $observeddelta) / $dseconds
      }]
      set observedharate [astrometry::foldradsymmetric [expr {
        ($futureobservedha - $observedha) / $dseconds
      }]]

    } else {
    
      set currentha      $requestedha
      set currentalpha   ""
      set currentdelta   $requesteddelta
      set currentequinox ""

      set standardequinox   ""
      set standardalpha     ""
      set standarddelta     ""
      set standardalpharate ""
      set standarddeltarate ""

      set aperturealphaoffset ""
      set aperturedeltaoffset ""

      set observedha     $currentha
      set observedalpha  [astrometry::foldradpositive [expr {[astrometry::last $seconds] - $observedha}]]
      set observeddelta  $currentdelta

      set observedalpharate ""
      set observeddeltarate ""
      set observedharate    ""

    }
    
    set observedazimuth        [astrometry::azimuth $observedha $observeddelta]
    set observedzenithdistance [astrometry::zenithdistance $observedha $observeddelta]
    set observedairmass        [astrometry::airmass $observedzenithdistance]

    set lastwithinlimits [server::getdata "withinlimits"]
    variable easthalimit
    variable westhalimit
    variable northdeltalimit
    variable southdeltalimit
    variable minzenithdistancelimit
    variable maxzenithdistancelimit
    if {
      ($observedha < $easthalimit) ||
      ($observedha > $westhalimit) ||
      ($observeddelta < $southdeltalimit) ||
      ($observeddelta > $northdeltalimit) ||
      ($observedzenithdistance < $minzenithdistancelimit) ||
      ($observedzenithdistance > $maxzenithdistancelimit)
    } {
      if {$lastwithinlimits} {
        log::warning "target is not within the limits."
      }
      set withinlimits false
    } else {
      set withinlimits true
    }

    server::setstatus "ok"

    server::setdata "last"                   [astrometry::last $seconds]
    server::setdata "currentalpha"           $currentalpha
    server::setdata "currentdelta"           $currentdelta
    server::setdata "currentha"              $currentha
    server::setdata "currentequinox"         $currentequinox
    server::setdata "standardalpha"          $standardalpha
    server::setdata "standarddelta"          $standarddelta
    server::setdata "standardalpharate"      $standardalpharate
    server::setdata "standarddeltarate"      $standarddeltarate
    server::setdata "standardequinox"        $standardequinox
    server::setdata "aperturealphaoffset"    $aperturealphaoffset
    server::setdata "aperturedeltaoffset"    $aperturedeltaoffset
    server::setdata "observedalpha"          $observedalpha
    server::setdata "observeddelta"          $observeddelta
    server::setdata "observedha"             $observedha
    server::setdata "observedazimuth"        $observedazimuth
    server::setdata "observedzenithdistance" $observedzenithdistance
    server::setdata "observedairmass"        $observedairmass
    server::setdata "observedalpharate"      $observedalpharate
    server::setdata "observeddeltarate"      $observeddeltarate
    server::setdata "observedharate"         $observedharate
    server::setdata "withinlimits"           $withinlimits
    server::setdata "timestamp"              [utcclock::combinedformat $seconds]
  }

  ######################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::setactivity "initializing"
    server::setrequestedactivity [server::getstoppedactivity]
    setrequestedpositiontoidle
    server::setactivity [server::getrequestedactivity]
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::setactivity "stopping"
    server::setrequestedactivity [server::getstoppedactivity]
    setrequestedpositiontoidle
    server::setactivity [server::getrequestedactivity]
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::setactivity "resetting"
    server::setrequestedactivity [server::getstoppedactivity]
    setrequestedpositiontoidle
    server::setactivity [server::getrequestedactivity]
  }
  
  proc move {ha delta} {
    server::checkstatus
    server::checkactivityformove
    set ha    [astrometry::parseha $ha]
    set delta [astrometry::parsedelta $delta]
    server::setactivity "moving"
    server::setrequestedactivity "idle"
    setrequestedposition \
      $ha "" $delta "" \
      "" "" \
      "" "" "" \
      "default"
    server::setactivity [server::getrequestedactivity]
  }

  proc track {alpha delta equinox alphaoffset deltaoffset epoch alpharate deltarate aperture} {
    server::checkstatus
    server::checkactivityformove
    pointing::checkaperture $aperture
    set alpha       [astrometry::parsealpha $alpha]
    set delta       [astrometry::parsedelta $delta]
    set equinox     [astrometry::parseequinox $equinox]
    set alphaoffset [astrometry::parseangle $alphaoffset]
    set deltaoffset [astrometry::parseangle $deltaoffset]
    set epoch       [utcclock::combinedformat [utcclock::scan $epoch]]
    set alpharate   [astrometry::parseangle $alpharate]
    set deltarate   [astrometry::parseangle $deltarate]
    server::setactivity "moving"
    server::setrequestedactivity "tracking"
    setrequestedposition \
      "" $alpha $delta $equinox \
      $alphaoffset $deltaoffset \
      $epoch $alpharate $deltarate \
      $aperture
    server::setactivity [server::getrequestedactivity]
  }

  proc offset {alphaoffset deltaoffset aperture} {
    server::checkstatus
    server::checkactivity "tracking"
    if {![string equal [server::getactivity] "tracking"]} {
      error "target activity is \"[server::getactivity]\" and not tracking."
    }
    set alphaoffset [astrometry::parseangle $alphaoffset dms]
    set deltaoffset [astrometry::parseangle $deltaoffset dms]
    server::setactivity "moving"
    server::setrequestedactivity "tracking"
    setrequestedposition \
      "" [server::getdata "requestedalpha"] [server::getdata "requesteddelta"] [server::getdata "requestedequinox"] \
      $alphaoffset $deltaoffset \
      [server::getdata "requestedepochtimestamp"] [server::getdata "requestedalpharate"] [server::getdata "requesteddeltarate"] \
      $aperture
    server::setactivity [server::getrequestedactivity]
  }
  
  ######################################################################

  set server::datalifeseconds 5

  proc start {} {
    server::setactivity "moving"
    server::setrequestedactivity "idle"
    setrequestedpositiontoidle
    server::setactivity [server::getrequestedactivity]
    coroutine::every 200 target::updateobservedposition
  }

}
