########################################################################

# This file is part of the UNAM telescope control system.

# $Id: focuseroptec.tcl 3571 2020-05-23 01:10:38Z Alan $

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

package provide "focuseroptec" 0.0

namespace eval "focuser" {

  variable settledelayseconds 1.0

  variable channel
  
  variable rawposition
  variable rawdescription
  variable rawmaxposition
  
  # The mapping between device type and description is defined in
  # Appendix A of the Optec "FocusLynx Command Reference" document.

  variable rawdescriptiondict {
    "OA" "Optec TCF-Lynx 2\""
    "OB" "Optec TCF-Lynx 3\""
    "OC" "Optec TCF-Lynx 2\" with Extended Travel"
    "OD" "Optec Fast Focus Secondary Focuser"
    "OE" "Optec TCF-S Classic converted"
    "OF" "Optec TCF-S3 Classic converted"
    "OG" "Optec Gemini"
    "FA" "FocusLynx QuickSync FT Hi-Torque"
    "FB" "FocusLynx QuickSync FT Hi-Speed"
    "FC" "FocusLynx QuickSync SV"
    "SA" "Starlight Focuser - FTF2008BCR"
    "SB" "Starlight Focuser - FTF2015BCR"
    "SC" "Starlight Focuser - FTF2020BCR"
    "SD" "Starlight Focuser - FTF2025"
    "SE" "Starlight Focuser - FTF2515B-A"
    "SF" "Starlight Focuser - FTF2525B-A"
    "SG" "Starlight Focuser - FTF2535B-A"
    "SH" "Starlight Focuser - FTF3015B-A"
    "SI" "Starlight Focuser - FTF3025B-A"
    "SJ" "Starlight Focuser - FTF3035B-A"
    "SK" "Starlight Focuser - FTF3515B-A"
    "SL" "Starlight Focuser - FTF3545B-A"
    "SM" "Starlight Focuser - AP27FOC3E"
    "SN" "Starlight Focuser - AP4FOC3E"
    "SO" "FeatherTouch Motor Hi-Speed"
    "SP" "FeatherTouch Motor Hi-Torque"
    "SQ" "Starlight Instruments - FTM with MicroTouch"
    "TA" "Televue Focuser – with Micro-Touch unipolar motor"
    "ZZ" "none"
  }
  
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
    
    # Send FHGETHUBINFO for debugging purposes.
    log::debug "openspecific: sending <FHGETHUBINFO>."
    puts $channel "<FHGETHUBINFO>"
    flush $channel
    log::debug "openspecific: waiting"
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "openspecific: line = \"$line\"."
    }    
    
    # Set device type.
    log::debug "openspecific: sending <F1SCDTxx>."
    puts $channel "<F1SCDTFA>"
    flush $channel
    log::debug "openspecific: waiting"
    while {[gets $channel line] && ![string equal $line "SET"]} {
      log::debug "openspecific: line = \"$line\"."
    }    

    # Send F1GETCONFIG to get the maximum position and device type.
    log::debug "openspecific: sending <F1GETCONFIG>."
    puts $channel "<F1GETCONFIG>"
    flush $channel
    log::debug "openspecific: waiting"
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "openspecific: line = \"$line\"."
      scan $line "Max Pos = %d" rawmaxposition
      scan $line "Dev Typ = %s" devicetype
    }
    if {[string equal $devicetype "FA"]} {
      # Observed to be incorrectly reported by F1GETCONFIG as 265535.
      set rawmaxposition 65535
    }

    # Send F1HOME to find the home position.
    log::debug "openspecific: sending <F1HOME>."
    puts $channel "<F1HOME>"
    flush $channel

    log::debug "openspecific: rawmaxposition = \"$rawmaxposition\"."
    log::debug "openspecific: devicetype = \"$devicetype\"."
    set rawdescription [dict get $rawdescriptiondict $devicetype]
    log::debug "openspecific: rawdescription = \"$rawdescription\"."
    
    
    # Works for 2000, 3000 but not 4000.

    variable rawposition
    
    set delaymilliseconds 2000

    focuserrawupdateposition
    set start $rawposition
    log::debug "moving in."
    puts $channel "<F1MIR1>"
    flush $channel
    coroutine::after $delaymilliseconds
    puts $channel "<F1ERM>"
    flush $channel
    focuserrawupdateposition
    set end $rawposition
    set speedin [expr {($start - $end) / double($delaymilliseconds)}]
    log::info [format "speed in is %.2f steps/ms." $speedin]
    
    focuserrawupdateposition
    set start $rawposition
    log::debug "moving out."
    puts $channel "<F1MOR1>"
    flush $channel
    coroutine::after $delaymilliseconds
    puts $channel "<F1ERM>"
    flush $channel
    focuserrawupdateposition
    set end $rawposition
    set speedout [expr {($end - $start) / double($delaymilliseconds)}]
    log::info [format "speed out is %.2f steps/ms." $speedout]
    
    variable speed
    if {$speedin > $speedout} {
      set speed $speedin
    } else {
      set speed $speedout
    }


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
    log::debug "focuserrawupdateposition: sending <F1GETSTATUS>."
    puts $channel "<F1GETSTATUS>"
    flush $channel
    while {[gets $channel line] && ![string equal $line "END"]} {
      log::debug "focuserrawupdateposition: line = \"$line\"."
      scan $line "Curr Pos = %d" rawposition
    }
    log::debug "focuserrawupdateposition: rawposition = $rawposition."
    return "ok"
  }
  
  proc focuserrawgetposition {} {
    variable rawposition
    return $rawposition
  }
  
  proc focuserrawsetposition {newposition} {
    variable channel
    log::debug "focuserrawsetposition: starting."
    if {$newposition < [focuserrawgetminposition] || $newposition > [focuserrawgetmaxposition]} {
      return "invalid position"
    } else {
      set line [format "<F1SCCP%06d>" $newposition]
      log::debug "focuserrawsetposition: sending \"$line\"."
      puts $channel $line
      flush $channel
    }
    log::debug "focuserrawsetposition: done."
    return "ok"
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
      variable rawposition
      variable speed
      set maxtime 500
      set dz [expr {abs($newposition - $rawposition)}]
      focuserrawupdateposition
      log::debug "focuserrawmove: moving from $rawposition to $newposition."
      while {$dz > $maxtime * $speed} {
        log::debug "focuserrawmove: moving for $maxtime ms from $rawposition."
        if {$newposition < $rawposition} {
          puts $channel "<F1MIR1>"
        } else {
          puts $channel "<F1MOR1>"
        }
        flush $channel
        coroutine::after $maxtime
        puts $channel "<F1ERM>"
        flush $channel
        focuserrawupdateposition
        set dz [expr {abs($newposition - $rawposition)}]
      }
      set time [expr {int($dz / $speed)}]
      log::debug "focuserrawmove: moving for $maxtime ms from $rawposition."
      if {$newposition < $rawposition} {
        puts $channel "<F1MIR1>"
      } else {
        puts $channel "<F1MOR1>"
      }
      flush $channel
      coroutine::after $maxtime
      puts $channel "<F1ERM>"
      flush $channel
      focuserrawupdateposition
    }
    log::debug "focuserrawmove: done."
    return "ok"
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "focuser.tcl"]
