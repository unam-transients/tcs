########################################################################

# This file is part of the UNAM telescope control system.

# $Id: constraints.tcl 3600 2020-06-11 00:18:39Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "log"
package require "swift"
package require "target"

package provide "constraints" 0.0

namespace eval "constraints" {

  variable svnid {$Id}

  ######################################################################

  variable easthalimit            [astrometry::parseha    [config::getvalue "target" "easthalimit"]]
  variable westhalimit            [astrometry::parseha    [config::getvalue "target" "westhalimit"]]
  variable northdeltalimit        [astrometry::parsedelta [config::getvalue "target" "northdeltalimit"]]
  variable southdeltalimit        [astrometry::parsedelta [config::getvalue "target" "southdeltalimit"]]
  variable minzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "minzenithdistancelimit"]]
  variable maxzenithdistancelimit [astrometry::parseangle [config::getvalue "target" "maxzenithdistancelimit"]]

  ######################################################################
  
  proc start {} {
    setwhy ""
  }
  
  ######################################################################

  variable focustimestamp ""

  proc focustimestamp {} {
    variable focustimestamp
    return $focustimestamp    
  }
  
  proc setfocustimestamp {timestamparg} {
    variable focustimestamp
    set focustimestamp $timestamparg
  }
  
  ######################################################################
  
  variable why

  proc setwhy {whyarg} {
    variable why
    set why $whyarg
  }
  
  proc why {} {
    variable why
    return $why
  }

  ######################################################################
  
  proc hasconstraint {constraints key} {
    if {[dict exists $constraints $key]} {
      return true
    } else {
      return false
    }
  }

  proc getconstraint {constraints key} {
    return [dict get $constraints $key]
  }
  
  ######################################################################

  proc getstart {visit seconds} {
    return $seconds
  }
  
  proc getend {visit seconds} {
    return [expr {$seconds + [visit::estimatedduration $visit]}]
  }
  
  ######################################################################

  proc checkwithintelescopepointinglimitsat {visit constraints seconds when} {  

    variable easthalimit
    variable westhalimit
    variable northdeltalimit
    variable southdeltalimit
    variable minzenithdistancelimit
    variable maxzenithdistancelimit

    log::debug "checking the target is within the telescope pointing limits at $when ([utcclock::format $seconds])."
    log::debug "target observed HA and delta at $when are [astrometry::formatha [visit::observedha $visit $seconds]] [astrometry::formatdelta [visit::observeddelta $visit $seconds]]."

    set delta [visit::observeddelta $visit $seconds]
    log::debug [format "checking the declination (%s) at $when against the southern limit (%s)." \
                 [astrometry::formatdelta $delta] \
                 [astrometry::formatdelta $southdeltalimit]]
    if {$delta < $southdeltalimit} {
      setwhy [format \
        "declination (%s) at $when is less than the southern limit (%s)." \
        [astrometry::formatdelta $delta] \
        [astrometry::formatdelta $southdeltalimit]]
      return false
    }

    log::debug [format "checking the declination (%s) at $when against the northern limit (%s)." \
                 [astrometry::formatdelta $delta] \
                 [astrometry::formatdelta $northdeltalimit]]
    if {$delta > $northdeltalimit} {
      setwhy [format \
        "declination (%s) at $when is more than the northern limit (%s)." \
        [astrometry::formatdelta $delta] \
        [astrometry::formatdelta $northdeltalimit]]
      return false
    }

    set ha [visit::observedha $visit $seconds]
    log::debug [format "checking the HA (%s) at $when against the eastern limit (%s)." \
                 [astrometry::formatha $ha] \
                 [astrometry::formatha $easthalimit]]
    if {$ha < $easthalimit} {
      setwhy [format \
        "HA (%s) at $when is less than the eastern limit (%s)." \
        [astrometry::formatha $ha] \
        [astrometry::formatha $easthalimit]]
      return false
    }
    log::debug [format "checking the HA (%s) at $when against the western limit (%s)." \
                 [astrometry::formatha $ha] \
                 [astrometry::formatha $westhalimit]]
    if {$ha > $westhalimit} {
      setwhy [format \
        "HA (%s) at $when is more than the western limit (%s)." \
        [astrometry::formatha $ha] \
        [astrometry::formatha $westhalimit]]
      return false
    }

    set zenithdistance [astrometry::zenithdistance $ha $delta]
    log::debug [format "checking the zenith distance (%.2fd) at $when against the minimum allowed (%.2fd)." \
                 [astrometry::radtodeg $zenithdistance] \
                 [astrometry::radtodeg $minzenithdistancelimit]]
    if {$zenithdistance < $minzenithdistancelimit} {
      setwhy [format \
        "zenith distance (%.2fd) at $when is less than than the minimum allowed (%.2fd)." \
        [astrometry::radtodeg $zenithdistance] \
        [astrometry::radtodeg $minzenithdistancelimit]]
      return false
    }
    log::debug [format "checking the zenith distance (%.2fd) at $when against the maxiumum allowed (%.2fd)." \
                 [astrometry::radtodeg $zenithdistance] \
                 [astrometry::radtodeg $maxzenithdistancelimit]]
    if {$zenithdistance > $maxzenithdistancelimit} {
      setwhy [format \
        "zenith distance (%.2fd) at $when is more than than the maximum allowed (%.2fd)." \
        [astrometry::radtodeg $zenithdistance] \
        [astrometry::radtodeg $maxzenithdistancelimit]]
      return false
    }

    return true
  }
  
  proc checkwithintelescopepointinglimits {visit constraints seconds} {  
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {![checkwithintelescopepointinglimitsat $visit $constraints $start "start"]} {
      return false
    } 
    if {![checkwithintelescopepointinglimitsat $visit $constraints $end "end"]} {
      return false
    }
    set startha [visit::observedha $visit $start]
    set endha   [visit::observedha $visit $end  ]
    log::debug [format "HA at start is %s." [astrometry::formatha $startha]]
    log::debug [format "HA at end is %s." [astrometry::formatha $endha]]
    if {$startha < 0 && $endha > 0} {
      log::debug [format "checking at transit."]
      set alpha [visit::alpha $visit $seconds]
      set delta [visit::delta $visit $seconds]
      set equinox [visit::equinox $visit $seconds]
      set transit [astrometry::nextobservedtransitseconds $alpha $delta $equinox $seconds]
      log::debug [format "START = %s END = %s TRANSIT = %s" [utcclock::format $start] [utcclock::format $end] [utcclock::format $transit]]
      log::debug [format "HA at transit is %s." [astrometry::formatha [visit::observedha $visit $transit]]]
      if {
        ![checkwithintelescopepointinglimitsat $visit $constraints $transit "transit"]
      } {
        return false
      }
    }
    return true
  }
  
  ######################################################################
  
  proc checkmindateat {visit constraints seconds when} {
    if {![hasconstraint $constraints "mindate"]} {
      log::debug "no minimum date constraint."
    } else {
      set mindate [getconstraint $constraints "mindate"]
      set mindate [utcclock::scan $mindate]
      log::debug [format \
        "checking the date (%s) at $when against the minimum allowed (%s)." \
        [utcclock::combinedformat $seconds 0 false] \
        [utcclock::combinedformat $mindate 0 false] \
      ]
      if {$seconds < $mindate} {
        setwhy [format \
          "date (%s) at $when is less than the minimum allowed (%s)." \
          [utcclock::combinedformat $seconds 0 false] \
          [utcclock::combinedformat $mindate 0 false]]
        return false
      }
    } 
    return true
  }
  
  proc checkmindate {visit constraints seconds} {
    # Only check the mindate at the start.
    set start [getstart $visit $seconds]
    return [checkminsunhaat $visit $constraints $start "start"]
  }
  
  proc checkmaxdateat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxdate"]} {
      log::debug "no maximum date constraint."
    } else {
      set maxdate [getconstraint $constraints "maxdate"]
      set maxdate [utcclock::scan $maxdate]
      log::debug [format \
        "checking the date (%s) at $when against the maximum allowed (%s)." \
        [utcclock::combinedformat $seconds 0 false] \
        [utcclock::combinedformat $maxdate 0 false] \
      ]
      if {$seconds > $maxdate} {
        setwhy [format \
          "date (%s) at $when is more than the maximum allowed (%s)." \
          [utcclock::combinedformat $seconds 0 false] \
          [utcclock::combinedformat $maxdate 0 false]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxdate {visit constraints seconds} {
    # Only check the maxdate at the start.
    set start [getstart $visit $seconds]
    return [checkmaxsunhaat $visit $constraints $start "start"]
  }
  
  proc checkminsunhaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minsunha"]} {
      log::debug "no minimum Sun HA constraint."
    } else {
      set minha [getconstraint $constraints "minsunha"]
      set minha [astrometry::parseha $minha]
      set sunha [astrometry::ha [astrometry::sunobservedalpha $seconds]]
      log::debug [format \
        "checking the HA of the Sun (%s) at $when against the minimum allowed (%s)." \
        [astrometry::formatha $sunha] \
        [astrometry::formatha $minha] \
      ]
      if {$sunha < $minha} {
        setwhy [format \
          "Sun HA (%s) at $when is less than the minimum allowed (%s)." \
          [astrometry::formatha $sunha] \
          [astrometry::formatha $minha]]
        return false
      }
    }
    return true
  }

  proc checkminsunha {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminsunhaat $visit $constraints $start "start"] &&
      [checkminsunhaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxsunhaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minsunha"]} {
      log::debug "no minimum Sun HA constraint."
    } else {
      set maxha [getconstraint $constraints "maxsunha"]
      set maxha [astrometry::parseha $maxha]
      set sunha [astrometry::ha [astrometry::sunobservedalpha $seconds]]
      log::debug [format \
        "checking the HA of the Sun (%s) at $when against the maximum allowed (%s)." \
        [astrometry::formatha $sunha] \
        [astrometry::formatha $maxha] \
      ]
      if {$sunha > $maxha} {
        setwhy [format \
          "Sun HA (%s) at $when is more than the maximum allowed (%s)." \
          [astrometry::formatha $sunha] \
          [astrometry::formatha $maxha]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxsunha {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxsunhaat $visit $constraints $start "start"] &&
      [checkmaxsunhaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminsunzenithdistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minsunzenithdistance"]} {
      log::debug "no minimum Sun zenith distance constraint."
    } else {  
      set minzenithdistance [getconstraint $constraints "minsunzenithdistance"]
      set minzenithdistance [astrometry::parseangle $minzenithdistance]
      set sunalpha [astrometry::sunobservedalpha $seconds]
      set sundelta [astrometry::sunobserveddelta $seconds]
      set sunha    [astrometry::ha $sunalpha $seconds]
      set sunzenithdistance [astrometry::zenithdistance $sunha $sundelta]
      log::debug [format \
        "checking the zenith distance of the Sun (%.2fd) at $when against the minimum allowed (%.2fd)." \
        [astrometry::radtodeg $sunzenithdistance] \
        [astrometry::radtodeg $minzenithdistance] \
      ]
      if {$sunzenithdistance < $minzenithdistance} {
        setwhy [format \
          "zenith distance of the Sun (%.2fd) at $when is less than the minimum allowed (%.fd)." \
          [astrometry::radtodeg $sunzenithdistance] \
          [astrometry::radtodeg $minzenithdistance]]
        return false
      }
    }
    return true
  }
  
  proc checkminsunzenithdistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminsunzenithdistanceat $visit $constraints $start "start"] &&
      [checkminsunzenithdistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxsunzenithdistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxsunzenithdistance"]} {
      log::debug "no maximum Sun zenith distance constraint."
    } else {  
      set maxzenithdistance [getconstraint $constraints "maxsunzenithdistance"]
      set maxzenithdistance [astrometry::parseangle $maxzenithdistance]
      set sunalpha [astrometry::sunobservedalpha $seconds]
      set sundelta [astrometry::sunobserveddelta $seconds]
      set sunha    [astrometry::ha $sunalpha $seconds]
      set sunzenithdistance [astrometry::zenithdistance $sunha $sundelta]
      log::debug [format \
        "checking the zenith distance of the Sun (%.2fd) at $when against the maximum allowed (%.2f)." \
        [astrometry::radtodeg $sunzenithdistance] \
        [astrometry::radtodeg $maxzenithdistance] \
      ]
      if {$sunzenithdistance > $maxzenithdistance} {
        setwhy [format \
          "zenith distance of the Sun (%.2fd) at $when is more than the maximum allowed (%.fd)." \
          [astrometry::radtodeg $sunzenithdistance] \
          [astrometry::radtodeg $maxzenithdistance]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxsunzenithdistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxsunzenithdistanceat $visit $constraints $start "start"] &&
      [checkmaxsunzenithdistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminmoondistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minmoondistance"]} {
      log::debug "no minimum Moon distance constraint."
    } else {  
      set mindistance [getconstraint $constraints "minmoondistance"]
      set mindistance [astrometry::parseangle $mindistance]
      set moonobservedalpha [astrometry::moonobservedalpha $seconds]
      set moonobserveddelta [astrometry::moonobserveddelta $seconds]
      set observedalpha [visit::observedalpha $visit $seconds]
      set observeddelta [visit::observeddelta $visit $seconds]
      set distance [astrometry::distance $moonobservedalpha $moonobserveddelta $observedalpha $observeddelta]
      log::debug [format \
        "checking the Moon distance of the target (%.2fd) at $when against the minimum allowed (%.2fd)." \
        [astrometry::radtodeg $distance] \
        [astrometry::radtodeg $mindistance] \
      ]
      if {$distance < $mindistance} {
        setwhy [format \
          "Moon distance (%.2fd) at $when is less than the minimum allowed (%.2fd)." \
          [astrometry::radtodeg $distance] \
          [astrometry::radtodeg $mindistance]]
        return false
      }
    }
    return true
  }
  
  proc checkminmoondistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminmoondistanceat $visit $constraints $start "start"] &&
      [checkminmoondistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxmoondistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxmoondistance"]} {
      log::debug "no maximum Moon distance constraint."
    } else {  
      set maxdistance [getconstraint $constraints "maxmoondistance"]
      set maxdistance [astrometry::parseangle $maxdistance]
      set moonobservedalpha [astrometry::moonobservedalpha $seconds]
      set moonobserveddelta [astrometry::moonobserveddelta $seconds]
      set observedalpha [visit::observedalpha $visit $seconds]
      set observeddelta [visit::observeddelta $visit $seconds]
      set distance [astrometry::distance $moonobservedalpha $moonobserveddelta $observedalpha $observeddelta]
      log::debug [format \
        "checking the moon distance of the target (%.2fd) at $when against the maximum allowed (%.2fd)." \
        [astrometry::radtodeg $distance] \
        [astrometry::radtodeg $maxdistance] \
      ]
      if {$distance > $maxdistance} {
        setwhy [format \
          "Moon distance (%.2fd) at $when is more than the maximum allowed (%.2fd)." \
          [astrometry::radtodeg $distance] \
          [astrometry::radtodeg $maxdistance]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxmoondistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxmoondistanceat $visit $constraints $start "start"] &&
      [checkmaxmoondistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminhaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minha"]} {
      log::debug "no minimum HA constraint."
    } else {  
      set minha [getconstraint $constraints "minha"]
      set minha [astrometry::parseha $minha]
      set observedha [visit::observedha $visit $seconds]
      log::debug [format \
        "checking the HA of the target (%s) at $when against the minimum allowed (%s)." \
        [astrometry::formatha $observedha] \
        [astrometry::formatha $minha] \
      ]
      if {$observedha < $minha} {
        setwhy [format \
          "HA (%s) at $when is less than the minimum allowed (%s)." \
          [astrometry::formatha $observedha] \
          [astrometry::formatha $minha]]
        return false
      }
    }
    return true
  }

  proc checkminha {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminhaat $visit $constraints $start "start"] &&
      [checkminhaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxhaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxha"]} {
      log::debug "no maximum HA constraint."
    } else {  
      set maxha [getconstraint $constraints "maxha"]
      set maxha [astrometry::parseha $maxha]
      set observedha [visit::observedha $visit $seconds]
      log::debug [format \
        "checking the HA of the target (%s) at $when against the maximum allowed (%s)." \
        [astrometry::formatha $observedha] \
        [astrometry::formatha $maxha] \
      ]
      if {$observedha > $maxha} {
        setwhy [format \
          "HA (%s) at $when is more than the maximum allowed (%s)." \
          [astrometry::formatha $observedha] \
          [astrometry::formatha $maxha]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxha {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxhaat $visit $constraints $start "start"] &&
      [checkmaxhaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmindeltaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "mindelta"]} {
      log::debug "no minimum delta constraint."
    } else {  
      set mindelta [getconstraint $constraints "mindelta"]
      set observeddelta [visit::observeddelta $visit $seconds]
      set mindelta [astrometry::parsedelta $mindelta]
      log::debug [format \
        "checking the delta of the target (%s) at $when against the minimum allowed (%s)." \
        [astrometry::formatdelta $observeddelta] \
        [astrometry::formatdelta $mindelta] \
      ]
      if {$observeddelta < $mindelta} {
        setwhy [format \
          "delta (%s) at $when is less than the minimum allowed (%s)." \
          [astrometry::formatdelta $observeddelta] \
          [astrometry::formatdelta $mindelta]]
        return false
      }
    }
    return true
  }

  proc checkmindelta {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmindeltaat $visit $constraints $start "start"] &&
      [checkmindeltaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxdeltaat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxdelta"]} {
      log::debug "no maximum delta constraint."
    } else {  
      set maxdelta [getconstraint $constraints "maxdelta"]
      set maxdelta [astrometry::parsedelta $maxdelta]
      set observeddelta [visit::observeddelta $visit $seconds]
      log::debug [format \
        "checking the delta of the target (%s) at $when against the maximum allowed (%s)." \
        [astrometry::formatdelta $observeddelta] \
        [astrometry::formatdelta $maxdelta] \
      ]
      if {$observeddelta > $maxdelta} {
        setwhy [format \
          "delta (%s) at $when is more then the maximum allowed (%s)." \
          [astrometry::formatdelta $observeddelta] \
         [astrometry::formatdelta $maxdelta]]
        return false
      }
    }
    return true
  }
  
  proc checkmaxdelta {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxdeltaat $visit $constraints $start "start"] &&
      [checkmaxdeltaat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminairmassat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minairmass"]} {
      log::debug "no minimum airmass constraint."
    } else { 
      set minairmass [getconstraint $constraints "minairmass"]
      set observedairmass [astrometry::airmass [astrometry::zenithdistance [visit::observedha $visit $seconds] [visit::observeddelta $visit $seconds]]]
      log::debug [format \
        "checking the airmass of the target (%.3f) at $when against the minimum allowed (%.3f)." \
           $observedairmass $minairmass \
        ]
      if {$observedairmass < $minairmass} {
        setwhy [format \
          "airmass (%.2f) at $when is less than the minimum allowed (%.2f)." \
          $observedairmass \
          $minairmass]
        return false
      }
    }
    return true
  }
  
  proc checkminairmass {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminairmassat $visit $constraints $start "start"] &&
      [checkminairmassat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxairmassat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxairmass"]} {
      log::debug "no maximum airmass constraint."
    } else { 
      set maxairmass [getconstraint $constraints "maxairmass"]
      set observedairmass [astrometry::airmass [astrometry::zenithdistance [visit::observedha $visit $seconds] [visit::observeddelta $visit $seconds]]]
      log::debug [format \
        "checking the airmass of the target (%.3f) at $when against the maximum allowed (%.3f)." \
          $observedairmass $maxairmass \
        ]
      if {$observedairmass > $maxairmass} {
        setwhy [format \
          "airmass (%.2f) at $when is more than the maximum allowed (%.2f)." \
          $observedairmass \
          $maxairmass]
        return false
      }
    }
    return true
  }
  
  proc checkmaxairmass {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxairmassat $visit $constraints $start "start"] &&
      [checkmaxairmassat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminzenithdistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minzenithdistance"]} {
      log::debug "no minimum zenith distance constraint."
    } else { 
      set minzenithdistance [astrometry::parseangle [getconstraint $constraints "minzenithdistance"]]
      set observedzenithdistance [astrometry::zenithdistance [visit::observedha $visit $seconds] [visit::observeddelta $visit $seconds]]
      log::debug [format \
        "checking the zenith distance of the target (%.1fd) at $when against the minimum allowed (%.1fd)." \
          [astrometry::radtodeg $observedzenithdistance] \
          [astrometry::radtodeg $minzenithdistance] \
        ]
      if {$observedzenithdistance < $minzenithdistance} {
        setwhy [format \
          "zenit distance (%.2f) at $when is less than the minimum allowed (%.2f)." \
          $observedzenithdistance \
          $minzenithdistance]
        return false
      }
    }
    return true
  }
  
  proc checkminzenithdistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminzenithdistanceat $visit $constraints $start "start"] &&
      [checkminzenithdistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxzenithdistanceat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxzenithdistance"]} {
      log::debug "no maximum zenith distance constraint."
    } else { 
      set maxzenithdistance [astrometry::parseangle [getconstraint $constraints "maxzenithdistance"]]
      set observedzenithdistance [astrometry::zenithdistance [visit::observedha $visit $seconds] [visit::observeddelta $visit $seconds]]
      log::debug [format \
        "checking the zenith distance of the target (%.1fd) at $when against the maximum allowed (%.1fd)." \
          [astrometry::radtodeg $observedzenithdistance] \
          [astrometry::radtodeg $maxzenithdistance] \
        ]
      if {$observedzenithdistance > $maxzenithdistance} {
        setwhy [format \
          "zenith distance (%.2f) at $when is more than the maximum allowed (%.2f)." \
          $observedzenithdistance \
          $maxzenithdistance]
        return false
      }
    }
    return true
  }
  
  proc checkmaxzenithdistance {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxzenithdistanceat $visit $constraints $start "start"] &&
      [checkmaxzenithdistanceat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc skybrightness {seconds} {
    set sunskystate  [astrometry::sunskystate $seconds]
    set moonskystate [astrometry::moonskystate $seconds]
    if {[string equal $sunskystate "night"]} {
      return $moonskystate
    } else {
      return $sunskystate
    }
  }
  
  proc checkminskybrightnessat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minskybrightness"]} {
      log::debug "no minimum sky brightness constraint."
    } else {
      set minskybrightness [getconstraint $constraints "minskybrightness"]
      set skybrightness [skybrightness $seconds]
      log::debug "checking the sky brightness ($skybrightness) at $when against the minimum allowed ($minskybrightness)."
      set skybrightnesslist {"dark" "grey" "bright" "astronomicaltwilight" "nauticaltwilight" "civiltwilight" "daylight"}
      set skybrightnessindex    [lsearch -exact $skybrightnesslist $skybrightness]
      set minskybrightnessindex [lsearch -exact $skybrightnesslist $minskybrightness]
      if {$skybrightnessindex < $minskybrightnessindex} {
        setwhy [format \
          "sky brightness (%s) at $when is less than the minimum allowed (%s)." \
          $skybrightness \
          $minskybrightness]
        return false
      }
    }
    return true
  }
  
  proc checkminskybrightness {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkminskybrightnessat $visit $constraints $start "start"] &&
      [checkminskybrightnessat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkmaxskybrightnessat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxskybrightness"]} {
      log::debug "no maximum sky brightness constraint."
    } else {
      set maxskybrightness [getconstraint $constraints "maxskybrightness"]
      set skybrightness [skybrightness $seconds]
      log::debug "checking the sky brightness ($skybrightness) at $when against the maximum allowed ($maxskybrightness)."
      set skybrightnesslist {"dark" "grey" "bright" "astronomicaltwilight" "nauticaltwilight" "civiltwilight" "daylight"}
      set skybrightnessindex    [lsearch -exact $skybrightnesslist $skybrightness]
      set maxskybrightnessindex [lsearch -exact $skybrightnesslist $maxskybrightness]
      if {$skybrightnessindex > $maxskybrightnessindex} {
        setwhy [format \
          "sky brightness (%s) at $when is more than the maximum allowed (%s)." \
          $skybrightness \
          $maxskybrightness]
        return false
      }
    }
    return true
  }
  
  proc checkmaxskybrightness {visit constraints seconds} {
    set start [getstart $visit $seconds]
    set end   [getend   $visit $seconds]
    if {
      [checkmaxskybrightnessat $visit $constraints $start "start"] &&
      [checkmaxskybrightnessat $visit $constraints $end   "end"  ]
    } {
      return true
    } else {
      return false
    }
  }
  
  proc checkminfocusdelayat {visit constraints seconds when} {
    if {![hasconstraint $constraints "minfocusdelay"]} {
      log::debug "no minimum focus delay constraint."
    } else {
      set mindelay [getconstraint $constraints "minfocusdelay"]
      variable focustimestamp
      log::debug "checking focus delay against the minimum allowed ($mindelay seconds)."
      if {[string equal "" $focustimestamp]} {
        return true
      }
      set delay [utcclock::diff $seconds $focustimestamp]
      if {$delay < $mindelay} {
        setwhy [format \
          "focus delay (%.0f seconds) at $when is less than minimum allowed (%.0f seconds)." \
          $delay \
          $mindelay]
        return false
      }
    }
    return true        
  }
  
  proc checkminfocusdelay {visit constraints seconds} {
    set start [getstart $visit $seconds]
    return [checkminfocusdelayat $visit $constraints $start "start"]
  }
  
  proc checkmaxfocusdelayat {visit constraints seconds when} {
    if {![hasconstraint $constraints "maxfocusdelay"]} {
      log::debug "no maximum focus delay constraint."
    } else {
      set maxdelay [getconstraint $constraints "maxfocusdelay"]
      variable focustimestamp
      log::debug "checking the focus delay against the maximum allowed ($maxdelay seconds)."
      if {[string equal "" $focustimestamp]} {
        setwhy "not focused."
        return false
      }
      set delay [utcclock::diff $seconds $focustimestamp]
      if {$delay > $maxdelay} {
        setwhy [format \
          "focus delay (%.0f seconds) at $when is more than maximum allowed (%.0f seconds)." \
          $delay \
          $maxdelay]
        return false
      }
    }
    return true        
  }
  
  proc checkmaxfocusdelay {visit constraints seconds} {
    set start [getstart $visit $seconds]
    return [checkmaxfocusdelayat $visit $constraints $start "start"]
  } 
  
  proc checkalertenabled {alert} {
    if {![string equal "" $alert]} {
      log::debug "checking alert is enabled."
      set alertenabled [alert::enabled $alert]
      if {!$alertenabled} {
        setwhy [format "alert is not enabled."]
        return false
      }
    }
    return true  
  }
  
  proc checkminalertdelay {alert constraints} {
    if {![string equal "" $alert]} {
      if {![hasconstraint $constraints "minalertdelay"]} {
        log::debug "no minimum alert delay constraint."
      } else {
        set mindelay [getconstraint $constraints "minalertdelay"]
        log::debug [format "checking the alert delay against the minimum allowed of %s." [utcclock::formatinterval $mindelay]]
        set delay [alert::delay $alert]
        if {$delay < $mindelay} {
          setwhy [format \
            "alert delay of %s is less than minimum allowed of %s." \
            [utcclock::formatinterval $delay] \
            [utcclock::formatinterval $mindelay] \
          ]
          return false
        }
      }
    }
    return true        
    
  }
  
  proc checkmaxalertdelay {alert constraints} {
    if {![string equal "" $alert]} {
      if {![hasconstraint $constraints "maxalertdelay"]} {
        log::debug "no maximum alert delay constraint."
      } else {
        set maxdelay [getconstraint $constraints "maxalertdelay"]
        log::debug [format "checking the alert delay against the maximum allowed of %s." [utcclock::formatinterval $maxdelay]]
        set delay [alert::delay $alert]
        if {$delay > $maxdelay} {
          setwhy [format \
            "alert delay of %s is more than maximum allowed of %s." \
            [utcclock::formatinterval $delay] \
            [utcclock::formatinterval $maxdelay] \
          ]
          return false
        }
      }
    }
    return true        
  }
  
  proc checkminalertuncertainty {alert constraints} {
    if {![string equal "" $alert]} {
      if {![hasconstraint $constraints "minalertuncertainty"]} {
        log::debug "no minimum alert uncertainty constraint."
      } else {
        set minuncertainty [getconstraint $constraints "minalertuncertainty"]
        log::debug [format "checking the alert uncertainty against the minimum allowed of %s." [astrometry::formatdistance $minuncertainty]]
        set uncertainty [alert::uncertainty $alert]
        if {$uncertainty < $minuncertainty} {
          setwhy [format \
            "alert uncertainty of %s is less than minimum allowed of %s." \
            [astrometry::formatdistance $uncertainty] \
            [astrometry::formatdistance $minuncertainty] \
          ]
          return false
        }
      }
    }
    return true
  }
  
  proc checkmaxalertuncertainty {alert constraints} {
    if {![string equal "" $alert]} {
      if {![hasconstraint $constraints "maxalertuncertainty"]} {
        log::debug "no maximum alert uncertainty constraint."
      } else {
        set maxuncertainty [getconstraint $constraints "maxalertuncertainty"]
        log::debug [format "checking the alert uncertainty against the maximum allowed of %s." [astrometry::formatdistance $maxuncertainty]]
        set uncertainty [alert::uncertainty $alert]
        if {$uncertainty > $maxuncertainty} {
          setwhy [format \
            "alert uncertainty of %s is more than maximum allowed of %s." \
            [astrometry::formatdistance $uncertainty] \
            [astrometry::formatdistance $maxuncertainty] \
          ]
          return false
        }
      }
    }
    return true
  }
  
  proc checkmustbeonfavoredsideforswiftat {visit constraints seconds when} {
    if {![hasconstraint $constraints "mustbeonfavoredsideforswift"]} {
      log::debug "no mustbeonfavoredsideforswift."
    } elseif {![getconstraint $constraints "mustbeonfavoredsideforswift"]} {
      log::debug "mustbeonfavoredsideforswift is false."
    } else {
      log::debug "mustbeonfavoredsideforswift is false."
      set favoredside [swift::favoredside]
      set observedha [visit::observedha $visit $seconds]
      log::debug [format \
        "checking the HA (%s) at $when is on the favored side for swift (%s)." \
        [astrometry::formatha $observedha] $favoredside \
      ]
      if {
        ([string equal $favoredside "east"] && $observedha > 0) ||
        ([string equal $favoredside "west"] && $observedha < 0)
      } {
        setwhy [format \
          "HA (%s) at $when is not on the favored side for swift (%s)." \
          [astrometry::formatha $observedha] $favoredside \
        ]
        return false
      }
    }
    return true    
  }
  
  proc checkmustbeonfavoredsideforswift {visit constraints seconds} {
    set start [getstart $visit $seconds]
    return [checkmustbeonfavoredsideforswiftat $visit $constraints $start "start"]
  } 
  
  ######################################################################
  
  proc check {visit constraints alert seconds} {

    log::debug [format "visit start is %s." [utcclock::format [getstart $visit $seconds]]]
    log::debug [format "visit end is %s." [utcclock::format [getend $visit $seconds]]]
    log::debug [format "estimated duration is %.0f seconds." [visit::estimatedduration $visit]]

    if {![checkalertenabled $alert]} {
      return false
    }

    if {![checkminalertuncertainty $alert $constraints]} {
      return false
    }
    if {![checkmaxalertuncertainty $alert $constraints]} {
      return false
    }
    if {![checkminalertdelay $alert $constraints]} {
      return false
    }
    if {![checkmaxalertdelay $alert $constraints]} {
      return false
    }

    if {![checkwithintelescopepointinglimits $visit $constraints $seconds]} {
      return false
    }
    
    if {![checkminskybrightness $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxskybrightness $visit $constraints $seconds]} {
      return false
    }

    if {![checkminsunha $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxsunha $visit $constraints $seconds]} {
      return false
    }
    if {![checkminsunzenithdistance $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxsunzenithdistance $visit $constraints $seconds]} {
      return false
    }

    if {![checkmindate $visit $constraints $seconds]} {
      return false
    }
    if {![checkmindate $visit $constraints $seconds]} {
      return false
    }

    if {![checkminfocusdelay $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxfocusdelay $visit $constraints $seconds]} {
      return false
    }

    if {![checkwithintelescopepointinglimits $visit $constraints $seconds]} {
      return false
    }
    
    if {![checkminha $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxha $visit $constraints $seconds]} {
      return false
    }
    if {![checkmindelta $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxdelta $visit $constraints $seconds]} {
      return false
    }
    if {![checkminzenithdistance $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxzenithdistance $visit $constraints $seconds]} {
      return false
    }
    if {![checkminairmass $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxairmass $visit $constraints $seconds]} {
      return false
    }

    if {![checkminmoondistance $visit $constraints $seconds]} {
      return false
    }
    if {![checkmaxmoondistance $visit $constraints $seconds]} {
      return false
    }
    
    if {![checkmustbeonfavoredsideforswift $visit $constraints $seconds]} {
      return false
    }

    return true  
  }
  
}
