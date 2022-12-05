########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "focusergemini" 0.0

namespace eval "focuser" {

  variable settledelayseconds 1.0

  variable channel
  
  variable rawposition        ""
  variable rawmaxposition     ""
  variable rawrotatorangle    ""
  variable rawrotatorposition ""
  variable rawdescription     "Optec Gemini"
  
  proc openspecific {identifier} {
    variable channel
    variable rawdescription
    variable rawdescriptiondict
    variable rawmaxposition
    
    log::debug "openspecific: starting."

    log::debug "openspecific: opening \"$identifier\"."
    if {[catch {set channel [::open $identifier "r+"]}]} {
      error "unable to open $identifier."
    }
    log::debug "openspecific: configuring."
    if {[catch {chan configure $channel -mode "115200,n,8,1" -handshake "none"}]} {
      error "unable to configure $identifier."
    }
    
    # Get the maximum position.
    log::debug "openspecific: sending <F100GETCFG>."
    puts $channel "<F100GETCFG>"
    flush $channel
    log::debug "openspecific: waiting"
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "openspecific: line = \"$line\"."
      scan $line "MaxSteps = %d" rawmaxposition
    }

    # Find the home position.
    log::debug "openspecific: sending <F100DOHOME>."
    puts $channel "<F100DOHOME>"
    flush $channel
    log::debug "openspecific: waiting"
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "openspecific: line = \"$line\"."
    }
    set ishomed 0
    while {!$ishomed} {
      log::debug "openspecific: sending <F100GETSTA>."
      puts $channel "<F100GETSTA>"
      flush $channel
      log::debug "openspecific: waiting"
      while {[gets $channel line] && ![string equal $line "END"]} {
        log::debug "openspecific: line = \"$line\"."
        scan $line "Is Homed = %d" ishomed
      }
      coroutine::after 1000
    }

    log::debug "openspecific: rawmaxposition = \"$rawmaxposition\"."
    log::debug "openspecific: rawdescription = \"$rawdescription\"."
    
    log::debug "openspecific: done."
    return "ok"
  }
  
  proc focuserrawclose {} {
    variable channel
    ::close $channel
  }
  
  proc focuserrawupdateposition {} {

    variable channel
    variable rawposition
    variable rawrotatorangle
    variable rawrotatorposition

    log::debug "focuserrawupdateposition: sending <F100GETSTA>."
    puts $channel "<F100GETSTA>"
    flush $channel
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "focuserrawupdateposition: line = \"$line\"."
      scan $line "CurrStep = %d" rawposition
    }
    log::debug "focuserrawupdateposition: rawposition = $rawposition."
    
    log::debug "focuserrawupdateposition: sending <R100GETSTA>."
    puts $channel "<R100GETSTA>"
    flush $channel
    set lastrawrotatorangle    $rawrotatorangle
    set lastrawrotatorposition $rawrotatorposition
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "focuserrawupdateposition: line = \"$line\"."
      scan $line "CurrStep = %d" rawrotatorposition
      scan $line "CurentPA = %d" rawrotatorangle
    }
    set rawrotatorangle [astrometry::degtorad [expr {$rawrotatorangle * 1e-4}]]
    log::debug "focuserrawupdateposition: rawrotatorangle    = $rawrotatorangle."
    log::debug "focuserrawupdateposition: rawrotatorposition = $rawrotatorposition."
    if {[string equal $lastrawrotatorposition ""] || $rawrotatorposition != $lastrawrotatorposition} {
      log::info [format "rotator position is %d." $rawrotatorposition]
    }
    if {[string equal $lastrawrotatorangle ""] || $rawrotatorangle != $lastrawrotatorangle} {
      log::info [format "rotator angle is %.4fd." [astrometry::radtodeg $rawrotatorangle]]
    }
    
    return "ok"
  }
  
  proc focuserrawgetposition {} {
    variable rawposition
    return $rawposition
  }
  
  proc focuserrawsetposition {newposition} {
    return "not possible with this hardware"
  }
  
  proc focuserrawgetdescription {} {
    variable rawdescription
    return $rawdescription
  }
  
  proc focuserrawgetminposition {} {
    return 0
  }

  proc focuserrawgetmaxposition {} {
    variable rawmaxposition 
    return $rawmaxposition
  }
  
  proc focuserrawmove {newposition} {
    variable channel
    log::debug "focuserrawmove: starting."
    if {$newposition < [focuserrawgetminposition] || $newposition > [focuserrawgetmaxposition]} {
      return "invalid position"
    } else {
      set line [format "<F100MOVABS%06d>" $newposition]
      log::debug "focuserrawmove: sending \"$line\"."
      puts $channel $line
      flush $channel
      while {[gets $channel line] && ![string equal $line "END"]} {
        log::debug "focuserrawupdateposition: line = \"$line\"."
      }
    }
    log::debug "focuserrawmove: done."
    return "ok"
  }
  
  proc focuserrawenable {} {
    return "ok"
  }
  
  proc focuserrawdisable {} {
    return "ok"
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "focuser.tcl"]
