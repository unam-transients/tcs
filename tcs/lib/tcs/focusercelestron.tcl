########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2024 Alan M. Watson <alan@astro.unam.mx>
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

# These are the raw procedures to use the Celestron focus motor.
#
# The motor has 1000 steps per revolution.

# See: 
#
#   https://www.celestron.com/products/focus-motor
#   https://github.com/indilib/indi/blob/master/drivers/focuser/celestron.cpp
#   http://paquettefamily.ca/nexstar/NexStar_AUX_Commands_10.pdf

package provide "focusercelestron" 0.0

namespace eval "focuser" {

  variable settledelayseconds 0.5

  variable channel
  
  variable rawdescription
  variable rawposition
  variable rawminposition
  variable rawmaxposition
  variable rawversion

  variable iscalibrated
  variable iscalibrating
  
  variable ccdidentifier [config::getvalue "ccd" "identifier"]
  variable softoffset [config::getvalue $ccdidentifier "focusersoftoffset"]
      
  proc openspecific {identifier} {

    variable channel
    variable rawdescription
    
    log::debug "openspecific: starting."

    log::debug "openspecific: opening \"$identifier\"."
    if {[catch {set channel [::open $identifier "r+"]}]} {
      error "unable to open $identifier."
    }
    log::debug "openspecific: configuring."
    if {[catch {chan configure $channel -mode "115200,n,8,1" -handshake "none" -translation "binary" -buffering "line"}]} {
      error "unable to configure $identifier."
    }
    
    flushinput

    variable rawdescription
    set rawdescription "Celestron focus motor"

    sendcommand "getversion"
    variable rawversion
    log::info "firmware version is $rawversion."
    
    variable iscalibrated
    variable iscalibrating
    sendcommand "calibrationstatus"

    if {$iscalibrated} {
      log::info "focuser is calibrated."
    } else {
      log::info "calibrating focuser."
      set start [utcclock::seconds]
      sendcommand "calibrate"
      sendcommand "calibrationstatus"
      while {$iscalibrating} {
        coroutine::after 2000
        sendcommand "calibrationstatus"
      }
      set end [utcclock::seconds]
      log::info [format "finished calibrating focuser after %.1f seconds." [expr {$end - $start}]]
    }

    variable rawminposition
    variable rawmaxposition
    sendcommand "getlimits"
    log::info "minimum position is $rawminposition."
    log::info "maximum position is $rawmaxposition."

    log::debug "openspecific: done."
    return "ok"
  }
  
  proc focuserrawclose {} {
    variable channel
    ::close $channel
  }
  
  proc flushinput {} {
    variable channel
    chan configure $channel -blocking false
    read $channel
    chan configure $channel -blocking true
  }
  
  variable preamble          0x3b
  variable remoteidentifier  0x20
  variable focuseridentifier 0x12
  
  proc sendpacket {commandbyte databytes} {

    variable channel
    
    variable preamble
    variable remoteidentifier
    variable focuseridentifier
    
    set payload [concat $remoteidentifier $focuseridentifier $commandbyte $databytes]

    set n [llength $payload]
    set checksum $n
    foreach byte $payload {
        set checksum [expr {$checksum + $byte}]
    }
    set checksum [expr {(-$checksum) & 0xff}]
    set packet [binary format "ccc*c" $preamble $n $payload $checksum]

    puts -nonewline $channel $packet
    flush $channel

  }
  
  proc readbyte {} {
    variable channel
    set c [coroutine::read $channel 1 100]
    binary scan $c "cu" byte
    return $byte
  }

  proc recvpacket {expectedcommandbyte} {
  
    variable preamble
    variable remoteidentifier 
    variable focuseridentifier
    
    log::debug "recvpacket: reading preamble."

    set byte [readbyte]
    if {$byte != $preamble} {
      error [format "unexpected preamble %02x in reply packet." $byte]
    }

    log::debug "recvpacket: reading length."
    set n [readbyte]

    log::debug "recvpacket: reading source."
    set sourcebyte [readbyte]
    if {$sourcebyte != $focuseridentifier} {
      error [format "unexpected source %02x in reply packet." $sourcebyte]
    }

    log::debug "recvpacket: reading destination."
    set destinationbyte [readbyte]
    if {$destinationbyte != $remoteidentifier} {
      error [format "unexpected destination %02x in reply packet." $destinationbyte]
    }

    log::debug "recvpacket: reading command."
    set commandbyte [readbyte]
    if {$commandbyte != $expectedcommandbyte} {
      error [format "unexpected command %02x in reply packet." $commandbyte]
    }
  
    log::debug "recvpacket: reading data."
    set i 0
    set ndatabytes [expr {$n - 3}]
    set databytes {}
    while {$i < $ndatabytes} {
      lappend databytes [readbyte]
      incr i
    }
  
    log::debug "recvpacket: reading checksum."
    set expectedchecksum $n
    set expectedchecksum [expr {$expectedchecksum + $sourcebyte}]
    set expectedchecksum [expr {$expectedchecksum + $destinationbyte}]
    set expectedchecksum [expr {$expectedchecksum + $commandbyte}]
    foreach byte $databytes {
      set expectedchecksum [expr {$expectedchecksum + $byte}]
    }
    set expectedchecksum [expr {(-$expectedchecksum) & 0xff}]
  
    set checksum [readbyte]
    if {$checksum != $expectedchecksum} {
      error [format "checksum error in reply packet."]
    }  
    
    log::debug "recvpacket: done."

  
    return $databytes
  
  }
  
  proc sendcommand {command args} {
  
    log::debug "sendcommand: $command $args"
  
    case $command {
      "rawupdateposition" {
        set commandbyte 0x01
        set databytes {}
      }
      "rawmove" {
        set commandbyte 0x17
        set position $args
        variable softoffset
        set rawposition [expr {$position + $softoffset}]
        set byte0 [expr {($rawposition >> 16) & 0xff}]
        set byte1 [expr {($rawposition >>  8) & 0xff}]
        set byte2 [expr {($rawposition >>  0) & 0xff}]
        set databytes [list $byte0 $byte1 $byte2]
      }
      "ismoving" {
        set commandbyte 0x13
        set databytes {}
      }
      "getversion" {
        set commandbyte 0xfe
        set databytes {}
      }
      "calibrate" {
        set commandbyte 0x2a
        set databytes { 0x01 }
      }
      "calibrationstatus" {
        set commandbyte 0x2b
        set databytes {}
      }
      "getlimits" {
        set commandbyte 0x2c
        set databytes {}
      }
      default {
        error "invalid command \"$command\"."
      }
    }

    #log::debug "sendcommand: flushing input."
    #flushinput

    set start [utcclock::seconds]
    log::debug "sendcommand: sending packet."
    sendpacket $commandbyte $databytes
    set end [utcclock::seconds]
    log::debug [format "sendcommand: finished sending packet after %.3f seconds." [expr {$end - $start}]]

    set start [utcclock::seconds]
    log::debug "sendcommand: receiving packet."
    set databytes [recvpacket $commandbyte]
    set end [utcclock::seconds]
    log::debug [format "sendcommand: finished receiving packet after %.3f seconds." [expr {$end - $start}]]

    log::debug "parsing received packet."
    case $command {
      "rawupdateposition" {
        if {[llength $databytes] != 3} {
          error "expected 3 data bytes."
        }
        set byte0 [lindex $databytes 0]
        set byte1 [lindex $databytes 1]
        set byte2 [lindex $databytes 2]
        variable rawposition
        set rawposition [expr {($byte0 << 16) + ($byte1 << 8) + $byte2}]
        variable softoffset
        variable position
        set position [expr {$rawposition - $softoffset}]
        log::debug "position = $position rawposition = $rawposition."
      }
      "ismoving" {
        if {[llength $databytes] != 1} {
          error "expected 1 data byte."
        }
        set byte0 [lindex $databytes 0]
        if {$byte0 == 0xff} {
          puts "slew done."
        } else {
          puts "slew not done"
        }
      }
      "getversion" {
        variable rawversion
        if {[llength $databytes] == 4} {
          set byte0 [lindex $databytes 0]
          set byte1 [lindex $databytes 1]
          set byte2 [lindex $databytes 2]
          set byte3 [lindex $databytes 3]
          set rawversion [format "%d.%d.%d" $byte0 $byte1 [expr {($byte2 << 8) + $byte3}]]
        } elseif {[llength $databytes] == 2} {
          set byte0 [lindex $databytes 0]
          set byte1 [lindex $databytes 1]
          set rawversion [format "%d.%d" $byte0 $byte1]
        } else {
          error "expected 2 or 4 data bytes."
        }
      }
      "calibrationstatus" {
        if {[llength $databytes] != 2} {
          error "expected 2 data bytes."
        }
        set byte0 [lindex $databytes 0]
        set byte1 [lindex $databytes 1]
        log::debug "focuser calibration state is $byte1."
        variable iscalibrated
        variable iscalibrating
        if {$byte0 > 0} {
          set iscalibrated  true
          set iscalibrating false
        } elseif {$byte1 == 0} {
          set iscalibrated  false
          set iscalibrating false
          log::warning "focuser calibration aborted."
        } else {
          set iscalibrated  false
          set iscalibrating true
        }
      }
      "getlimits" {
        if {[llength $databytes] != 8} {
          error "expected 8 data bytes."
        }
        set byte0 [lindex $databytes 0]
        set byte1 [lindex $databytes 1]
        set byte2 [lindex $databytes 2]
        set byte3 [lindex $databytes 3]
        set byte4 [lindex $databytes 4]
        set byte5 [lindex $databytes 5]
        set byte6 [lindex $databytes 6]
        set byte7 [lindex $databytes 7]
        variable rawminposition
        variable rawmaxposition
        set rawminposition [expr {($byte0 << 24) + ($byte1 << 16) + ($byte2 << 8) + $byte3}]
        set rawmaxposition [expr {($byte4 << 24) + ($byte5 << 16) + ($byte6 << 8) + $byte3}]
      }
    }
    
    log::debug "sendcommand: done."
    
  }
  
  proc focuserrawupdateposition {} {
    sendcommand "rawupdateposition"
    return "ok"
  }
  
  proc focuserrawgetposition {} {
    variable position
    return $position
  }
  
  proc focuserrawsetposition {newposition} {
    variable ccdidentifier
    variable softoffset
    variable position
    set rawposition [expr {$position + $softoffset}]
    set softoffset [expr {$rawposition - $newposition}]
    config::setvarvalue $ccdidentifier "focusersoftoffset" $softoffset
    return "ok"
  }
  
  proc focuserrawgetdescription {} {
    variable rawdescription
    return $rawdescription
  }
  
  proc focuserrawgetminposition {} {
    variable rawminposition 
    return $rawminposition
  }

  proc focuserrawgetmaxposition {} {
    variable rawmaxposition 
    return $rawmaxposition
  }
  
  proc focuserrawmove {newposition} {
    log::debug "focuserrawmove: starting."
    if {$newposition < [focuserrawgetminposition] || $newposition > [focuserrawgetmaxposition]} {
      return "invalid position"
    }
    sendcommand rawmove $newposition
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
