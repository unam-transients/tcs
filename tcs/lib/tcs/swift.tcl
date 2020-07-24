########################################################################

# This file is part of the RATTEL telescope control system.

# $Id: swift.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "client"
package require "target"

package provide "swift" 0.0

namespace eval "swift" {

  variable svnid {$Id}

  ######################################################################
  
  variable pointingsource      [config::getvalue "swift" "pointingsource"]

  variable easthalimit            [astrometry::parseangle [config::getvalue "target" "easthalimit"]     "hms"]
  variable westhalimit            [astrometry::parseangle [config::getvalue "target" "westhalimit"]     "hms"]
  variable northdeltalimit        [astrometry::parseangle [config::getvalue "target" "northdeltalimit"] "dms"]
  variable southdeltalimit        [astrometry::parseangle [config::getvalue "target" "southdeltalimit"] "dms"]
  variable minzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "minzenithdistancelimit"]]
  variable maxzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "maxzenithdistancelimit"]]

  ######################################################################

  variable favoredside
  
  proc favoredside {} {
    variable favoredside
    return $favoredside
  }

  proc updatefavoredside {} {
  
    variable pointingsource
    variable favoredside
    
    if {[string equal $pointingsource "none"]} {

      set favoredside "none"
      return

    } elseif {[string equal $pointingsource "gcntan"]} {

      if {[catch {client::update "gcntan"} message]} {
        log::warning "unable to obtain swift pointing from gcntan server: $message"
        set favoredside "none"
        return
      }

      set alpha   [client::getdata "gcntan" "swiftalpha"]
      set delta   [client::getdata "gcntan" "swiftdelta"]
      set equinox [client::getdata "gcntan" "swiftequinox"]

    } else {
    
      log::warning "invalid swift pointing source: \"$pointingsource\"."
      set favoredside "none"
      return
      
    }

    if {[string equal $alpha ""] || [string equal $delta ""] || [string equal $equinox ""]} {
      log::info "swift: unable to determine favored side: no pointing information."
      set favoredside "none"
      return
    }

    set swiftalpha   [astrometry::parsealpha   $alpha]
    set swiftdelta   [astrometry::parsedelta   $delta]
    set swiftequinox [astrometry::parseequinox $equinox]
    
    log::info [format "swift: pointing is %s %s %.2f." [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]

    set seconds [utcclock::seconds]
    set swiftobservedalpha [astrometry::observedalpha $swiftalpha $swiftdelta $swiftequinox $seconds]
    set swiftobserveddelta [astrometry::observeddelta $swiftalpha $swiftdelta $swiftequinox $seconds]
    set swiftobservedha [astrometry::ha $swiftobservedalpha $seconds]

    log::info [format "swift: observed pointing is %s %s." [astrometry::formatha $swiftobservedha] [astrometry::formatdelta $swiftobserveddelta]]
    
    variable easthalimit
    variable westhalimit
    variable northdeltalimit
    variable southdeltalimit
    variable minzenithdistancelimit
    variable maxzenithdistancelimit

    # We estimate the fraction of the observable sky in the east and the
    # west that falls within the Swift/BAT field of view. The half-coded
    # field of about 100 x 60 degrees; we will take it to be 50 degrees
    # in radius.
    
    # https://swift.gsfc.nasa.gov/about_swift/bat_desc.html
    
    set swiftmaxdistance [astrometry::degtorad 50]
    
    set eastcount 0.0
    set westcount 0.0
    set totalcount 0.0

    set dmu 0.01
    set mu [expr {1 - 0.5 * $dmu}]
    while {$mu > -1} {
      #log::info [format "getfavoredside: mu = %.3f" $mu]
      set delta [expr {0.5 * [astrometry::pi] - acos($mu)}]
      #log::info [format "getfavoredside: delta = %.1fd" [astrometry::radtodeg $delta]]
      set dabsha [expr {0.01 * [astrometry::pi]}]
      set absha [expr {0.5 * $dabsha}]
      while {$absha < [astrometry::pi]} {
        #log::info [format "getfavoredside: absha = %.1fd" [astrometry::radtodeg $absha]]
        set ha $absha
        set zenithdistance [astrometry::zenithdistance $ha $delta]
        set alpha [astrometry::alpha $ha $seconds]
        set distance [astrometry::distance $alpha $delta $swiftobservedalpha $swiftobserveddelta]
        if {$distance < $swiftmaxdistance} {
          set totalcount [expr {$totalcount + 1}]
          if {
            $delta >= $southdeltalimit &&
            $delta <= $northdeltalimit &&
            $ha >= $easthalimit &&
            $ha <= $westhalimit &&
            $zenithdistance >= $minzenithdistancelimit &&
            $zenithdistance <= $maxzenithdistancelimit
          } {
            set westcount [expr {$westcount + 1}]
          }
        }
        set ha [expr {-$absha}]
        set zenithdistance [astrometry::zenithdistance $ha $delta]
        set alpha [astrometry::alpha $ha $seconds]
        set distance [astrometry::distance $alpha $delta $swiftobservedalpha $swiftobserveddelta]
        if {$distance < $swiftmaxdistance} {
          set totalcount [expr {$totalcount + 1}]
          if {
            $delta >= $southdeltalimit &&
            $delta <= $northdeltalimit &&
            $ha >= $easthalimit &&
            $ha <= $westhalimit &&
            $zenithdistance >= $minzenithdistancelimit &&
            $zenithdistance <= $maxzenithdistancelimit
          } {
            set eastcount [expr {$eastcount + 1}]
          }
        }
        set absha [expr {$absha + $dabsha}]
      }
      set mu [expr {$mu - $dmu}]
    }
    
    set eastfraction [expr {$eastcount / $totalcount}]
    set westfraction [expr {$westcount / $totalcount}]

    log::info [format "swift: fraction of bat field in east is %.2f." $eastfraction]
    log::info [format "swift: fraction of bat field in west is %.2f." $westfraction]

    if {$eastfraction > 0.05 && $eastfraction > $westfraction} {
      set favoredside "east"
    } elseif {$westfraction > 0.05 && $westfraction > $eastfraction} {
      set favoredside "west"
    } else {
      set favoredside "none"
    }
    
    log::info [format "swift: favored side is %s." $favoredside]
  }
    
  ######################################################################
  
}
