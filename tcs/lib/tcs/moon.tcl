########################################################################

# This file is part of the UNAM telescope control system.

# $Id: moon.tcl 3588 2020-05-26 23:41:05Z Alan $

########################################################################

# Copyright © 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "moon" 0.0

namespace eval "moon" {

  variable svnid {$Id}

  ######################################################################

  variable lastskystate ""
  
  proc updateobservedposition {} {
    
    variable lastskystate

    set seconds [utcclock::seconds]

    set observedalpha [astrometry::moonobservedalpha $seconds]
    set observeddelta [astrometry::moonobserveddelta $seconds]
    set observedha    [astrometry::ha $observedalpha $seconds]

    set observedazimuth        [astrometry::equatorialtoazimuth        $observedha $observeddelta]
    set observedzenithdistance [astrometry::equatorialtozenithdistance $observedha $observeddelta]
    
    set skystate [astrometry::moonskystate $seconds]
    if {![string equal $lastskystate ""]} {
      if {![string equal $lastskystate $skystate]} {
        log::summary "sky state changed from \"$lastskystate\" to \"$skystate\"."
      }
    }
    set lastskystate $skystate
    
    set illuminatedfraction [astrometry::moonilluminatedfraction $seconds]
    
    if {[catch {
      client::update "target"
      set targetobservedalpha [client::getdata "target" "observedalpha"]
      set targetobserveddelta [client::getdata "target" "observeddelta"]
    }]} {
      set observedtargetdistance ""
    } else {
      set observedtargetdistance [astrometry::distance $targetobservedalpha $targetobserveddelta $observedalpha $observeddelta]
    }

    server::setstatus "ok"
    if {![string equal [server::getactivity] "error"]} {    
      server::setactivity [server::getrequestedactivity]
    }

    server::setdata "observedalpha"            $observedalpha
    server::setdata "observeddelta"            $observeddelta
    server::setdata "observedha"               $observedha
    server::setdata "observedazimuth"          $observedazimuth
    server::setdata "observedzenithdistance"   $observedzenithdistance
    server::setdata "illuminatedfraction"      $illuminatedfraction
    server::setdata "observedtargetdistance"   $observedtargetdistance
    server::setdata "skystate"                 $skystate
    server::setdata "timestamp"                [utcclock::combinedformat $seconds]
  }

  ######################################################################

  set server::datalifeseconds 5

  proc start {} {
    server::setrequestedactivity "idle"
    coroutine::every 1000 moon::updateobservedposition
  }

}
