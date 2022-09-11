########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "finders"

package provide "telescoperatiroan" 0.0

namespace eval "telescope" {

  ######################################################################
  
  variable identifier "ratiroan"

  ######################################################################

  server::setdata "pointingtolerance" [astrometry::parseangle "5as"]
  server::setdata "pointingmode"      "finder"
  server::setdata "guidingmode"       "none"
  
  variable validpointingmodes { none finder }
  variable validguidingmodes  { none finder C0 C1 }

  variable mechanisms { covers mount dome shutters secondary nefinder sefinder guider }
  variable withlights true
  variable withheater false
    
  ######################################################################
  
  proc ringalarmbell {} {
    client::waituntilstarted "power"
    log::info "ringing the alarm bell."
    client::request "power" "switchon alarm-bell"
    client::wait "power"
    coroutine::after 10000
    client::request "power" "switchoff alarm-bell"
    client::wait "power"
    log::info "finished ringing the alarm bell."
  }

  proc switchcontacts {state contacts} {
    client::waituntilstarted "power"
    foreach contact $contacts {
      log::info "switching $state $contact."
      client::request "power" "switch$state $contact"
      client::wait "power"
      log::info "finished switching $state $contact."
    } 
  }

  ######################################################################

  proc initializeprolog {} {
    ringalarmbell
  }

  proc initializeepilog {} {
  }
  
  proc openprolog {} {
    ringalarmbell
    client::request "inclinometers" "suspend"
    switchcontacts "on" {finder-ccd-pump}
  }

  proc openepilog {} {
    client::request "inclinometers" "resume"
  }

  proc closeprolog {} {
    ringalarmbell
    client::request "inclinometers" "suspend"
  }

  proc closeepilog {} {
    client::request "inclinometers" "resume"
    switchcontacts "off" {finder-ccd-pump}
  }

  ######################################################################
  
  proc initializemechanismprolog {mechanism} {
    switch $mechanism {
      "mount" {
        switchcontacts "on" {mount-motors}
      }
      "shutters" {
         movedomeforshutter
        }
      "covers" {
        client::request "inclinometers" "suspend"
      }
    }
  }

  proc initializemechanismepilog {mechanism} {
    switch $mechanism {
      "covers" {
        client::request "inclinometers" "resume"
      }
      "shutters" {
        log::info "parking dome."
        client::request "dome" "preparetomove"
        client::request "dome" "park"
        client::wait "dome"
      }
    }
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "telescope.tcl"]
