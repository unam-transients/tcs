########################################################################

# This file is part of the UNAM telescope control system.

# $Id: sun.tcl 3588 2020-05-26 23:41:05Z Alan $

########################################################################

# Copyright © 2011, 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "client"
package require "coroutine"
package require "server"
package require "utcclock"

package provide "sun" 0.0

namespace eval "sun" {
  
  variable svnid {$Id}

  ######################################################################

  variable startofday
  variable endofday
  variable startofnight
  variable endofnight

  variable lastskystate         ""
  
  proc startdata {} {

    variable startofday
    variable endofday
    variable startofnight
    variable endofnight

    set seconds [utcclock::seconds]
    
    set skystate [astrometry::sunskystate $seconds]

    switch $skystate {
      "daylight" {
        set endofdayseconds     [astrometry::nextsunskystateseconds "civiltwilight"        $seconds]
        set startofnightseconds [astrometry::nextsunskystateseconds "night"                $endofdayseconds]
        set endofnightseconds   [astrometry::nextsunskystateseconds "astronomicaltwilight" $startofnightseconds]
        set startofdayseconds   [astrometry::nextsunskystateseconds "daylight"             $endofnightseconds]
      }
      "night" {
        set endofnightseconds   [astrometry::nextsunskystateseconds "astronomicaltwilight" $seconds]
        set startofdayseconds   [astrometry::nextsunskystateseconds "daylight"             $endofnightseconds]
        set endofdayseconds     [astrometry::nextsunskystateseconds "civiltwilight"        $startofdayseconds]
        set startofnightseconds [astrometry::nextsunskystateseconds "night"                $endofdayseconds]
      }
      default {
        set startofdayseconds   [astrometry::nextsunskystateseconds "daylight"             $seconds]
        set startofnightseconds [astrometry::nextsunskystateseconds "night"                $seconds]
        set endofdayseconds     [astrometry::nextsunskystateseconds "civiltwilight"        $startofdayseconds]
        set endofnightseconds   [astrometry::nextsunskystateseconds "astronomicaltwilight" $startofnightseconds]
      }
    }
    set startofday   [utcclock::combinedformat $startofdayseconds   0]
    set endofday     [utcclock::combinedformat $endofdayseconds     0]
    set startofnight [utcclock::combinedformat $startofnightseconds 0]
    set endofnight   [utcclock::combinedformat $endofnightseconds   0]

    updatedata
  }

  proc updatedata {} {
    
    variable startofday
    variable endofday
    variable startofnight
    variable endofnight

    variable lastskystate
    
    set seconds [utcclock::seconds]
    
    set observedalpha [astrometry::sunobservedalpha $seconds]
    set observeddelta [astrometry::sunobserveddelta $seconds]
    set observedha    [astrometry::ha $observedalpha $seconds]

    set observedazimuth        [astrometry::equatorialtoazimuth        $observedha $observeddelta]
    set observedzenithdistance [astrometry::equatorialtozenithdistance $observedha $observeddelta]

    if {[catch {
      client::update "target"
      set targetobservedalpha [client::getdata "target" "observedalpha"]
      set targetobserveddelta [client::getdata "target" "observeddelta"]
    }]} {
      set observedtargetdistance ""
    } else {
      set observedtargetdistance [astrometry::distance $targetobservedalpha $targetobserveddelta $observedalpha $observeddelta]
    }

    set skystate [astrometry::sunskystate $seconds]    
    if {![string equal $lastskystate ""]} {
      if {![string equal $lastskystate $skystate]} {
        log::summary "sky state changed from \"$lastskystate\" to \"$skystate\"."
        updatenextskystates $lastskystate $skystate
      }
    }
    set lastskystate $skystate

    server::setdata "observedalpha"            $observedalpha
    server::setdata "observeddelta"            $observeddelta
    server::setdata "observedha"               $observedha
    server::setdata "observedazimuth"          $observedazimuth
    server::setdata "observedzenithdistance"   $observedzenithdistance
    server::setdata "observedtargetdistance" $observedtargetdistance
    server::setdata "skystate"                 $skystate
    server::setdata "startofday"               $startofday
    server::setdata "endofday"                 $endofday
    server::setdata "startofnight"             $startofnight
    server::setdata "endofnight"               $endofnight
    server::setdata "timestamp"                [utcclock::combinedformat $seconds]

    server::setstatus "ok"
    if {![string equal [server::getactivity] "error"]} {    
      server::setactivity [server::getrequestedactivity]
    }

  }

  ######################################################################
  
  proc updatenextskystates {lastskystate skystate} {
    variable startofday
    variable endofday
    variable startofnight
    variable endofnight
    switch $lastskystate-$skystate {
      night-astronomicaltwilight {
        set seconds [utcclock::scan $startofnight]
        set seconds [astrometry::nextsunskystateseconds "night" $seconds]
        set seconds [astrometry::nextsunskystateseconds "astronomicaltwilight" $seconds]
        set endofnight [utcclock::combinedformat $seconds 0]
        log::info "next end of night is at [utcclock::format $seconds 0]."
      }
      astronomicaltwilight-night {
        set seconds [utcclock::scan $endofday]
        set seconds [astrometry::nextsunskystateseconds "astronomicaltwilight" $seconds]
        set seconds [astrometry::nextsunskystateseconds "night" $seconds]
        set startofnight [utcclock::combinedformat $seconds 0]
        log::info "next start of night is at [utcclock::format $seconds 0]."
      }
      daylight-civiltwilight {
        set seconds [utcclock::scan $startofday]
        set seconds [astrometry::nextsunskystateseconds "daylight" $seconds]
        set seconds [astrometry::nextsunskystateseconds "civiltwilight" $seconds]
        set endofday [utcclock::combinedformat $seconds 0]
        log::info "next end of day is at [utcclock::format $seconds 0]."
      }
      civiltwilight-daylight {
        set seconds [utcclock::scan $endofnight]
        set seconds [astrometry::nextsunskystateseconds "civiltwilight" $seconds]
        set seconds [astrometry::nextsunskystateseconds "daylight" $seconds]
        set startofday [utcclock::combinedformat $seconds 0]
        log::info "next start of day is at [utcclock::format $seconds 0]."
      }
    }
  }
  
  ######################################################################

  set server::datalifeseconds 5

  proc start {} {
    startdata
    server::setrequestedactivity "idle"
    coroutine::every 1000 sun::updatedata
  }

}
