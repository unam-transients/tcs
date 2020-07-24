########################################################################

# This file is part of the UNAM telescope control system.

# $Id: telescopeddotioan.tcl 3579 2020-05-23 21:52:55Z Alan $

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

package provide "telescopeddotioan" 0.0

namespace eval "telescope" {

  ######################################################################
  
  variable identifier "ddotioan"

  ######################################################################

  server::setdata "pointingtolerance" [astrometry::parseangle "5as"]
  server::setdata "pointingmode"      "none"
  server::setdata "guidingmode"       "none"
  
  variable validpointingmodes { none }
  variable validguidingmodes  { none }
  variable mechanisms { mount enclosure }

  ######################################################################

  proc switchlights {state} {
    client::waituntilstarted "lights"
    log::info "switching lights $state."
    client::request "lights" "switch$state"
    client::wait "lights"
  }
  
  ######################################################################
  
  proc switchheater {state} {
    client::waituntilstarted "heater"
    log::info "switching heater $state."
    client::request "heater" "switch$state"
    client::wait "heater"
  }
  
  ######################################################################

  proc initializeprolog {} {
    switchlights "on"
    switchheater "automatically"
  }

  proc initializeepilog {} {
    switchlights "off"
  }

  proc openprolog {} {
    switchlights "on"
    switchheater "off"
  }

  proc openepilog {} {
    switchlights "off"
  }

  proc closeprolog {} {
    switchlights "on"
  }

  proc closeepilog {} {
    switchlights "off"
    switchheater "automatically"
  }

  ######################################################################

  proc initializemechanismprolog {mechanism} {
  }

  proc initializemechanismepilog {mechanism} {
  }

  ######################################################################
}

source [file join [directories::prefix] "lib" "tcs" "telescope.tcl"]
