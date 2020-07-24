########################################################################

# This file is part of the UNAM telescope control system.

# $Id: finders.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2011, 2012, 2014, 2015, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "finders" 0.0

namespace eval "finders" {

  variable svnid {$Id}

  ######################################################################

  variable finders [config::getvalue "telescope" "finders"]
  variable minexposuretime [config::getvalue "finders" "minexposuretime"]
  variable maxexposuretime [config::getvalue "finders" "maxexposuretime"]

  ######################################################################
  
  variable solvedfinder ""
  variable exposuretime $minexposuretime
  
  ######################################################################
  
  proc getsolvedfinder {} {
    variable solvedfinder
    return $solvedfinder
  }
  
  proc getexposuretime {} {
    variable exposuretime
    return $exposuretime
  }
  
  ######################################################################
  
  proc isidle {finder} {
    if {[catch {client::update $finder}]} {
      return false
    } elseif {[string equal "idle" [client::getdata $finder "activity"]]} {
      return true
    } else {
      return false
    }
  }
  
  proc expose {exposuretime {exposuretype "object"}} {
    variable finders
    foreach finder $finders {
      client::request $finder "stop"
    }
    foreach finder $finders {
      while {![isidle $finder]} {
        coroutine::after 100
      }    
    }
    foreach finder $finders {
      client::request $finder "expose $exposuretime $exposuretype"
    }
    foreach finder $finders {
      while {![isidle $finder]} {
        coroutine::after 100
      }    
    }
  }
  
  proc getfinderastrometry {} {
    variable finders
    variable solvedfinder
    variable exposuretime
    variable maxexposuretime
    variable minexposuretime
    set exposuretime [expr {max($exposuretime * 0.95, $minexposuretime)}]
    set exposuretime [format "%.3f" $exposuretime]
    set solvedfinder ""
    foreach finder $finders {
      client::request $finder "stop"
    }
    while {true} {
      foreach finder $finders {
        while {![isidle $finder]} {
          coroutine::after 100
        }    
      }
      foreach finder $finders {
        client::request $finder "expose $exposuretime astrometry"
      }
      set idlefinder ""
      while {[string equal $idlefinder ""]} {
        foreach finder $finders {
          if {[isidle $finder]} {
            set idlefinder $finder
            break
          }
        }
        coroutine::after 100
      }
      if {![string equal [client::getdata $idlefinder "mountobservedalpha"] "unknown"]} {
        break
      }
      if {$exposuretime == $maxexposuretime} {
        log::warning "unable determine astrometry."
        return
      }
      log::info "increasing finders exposure time."
      set exposuretime [expr {min($exposuretime * 2, $maxexposuretime)}]
      set exposuretime [format "%.3f" $exposuretime]
    }
    set solvedfinder $idlefinder
    log::info "astrometry determined from $solvedfinder."
    return
  }
  
  ######################################################################
  
  
}
