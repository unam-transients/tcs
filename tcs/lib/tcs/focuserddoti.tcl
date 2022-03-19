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

package provide "focuserddoti" 0.0

namespace eval "focuser" {

  variable settledelayseconds 0.5

  variable channel
  
  variable rawdescription
  variable rawposition
  variable rawminposition
  variable rawmaxposition
  
  proc openspecific {identifier} {

    variable channel
    variable rawdescription
    variable rawminposition
    variable rawmaxposition
    
    log::debug "openspecific: starting."

    log::debug "openspecific: opening \"$identifier\"."
    if {[catch {set channel [::open $identifier "r+"]}]} {
      error "unable to open $identifier."
    }
    log::debug "openspecific: configuring."
    if {[catch {chan configure $channel -mode "115200,n,8,1" -handshake "none" -translation "binary" -buffering "line"}]} {
      error "unable to configure $identifier."
    }
    
    set rawminposition [expr {int(-pow(2, 31))}]
    set rawmaxposition [expr {int(pow(2, 31) - 1)}]
    
    log::debug "openspecific: sending GC."
    sendcommand "GC"
    log::debug "openspecific: sending ID."
    sendcommand "ID"
    log::debug "openspecific: sending PO."
    sendcommand "PO"
    
    log::debug "openspecific: done."
    return "ok"
  }
  
  proc focuserrawclose {} {
    variable channel
    ::close $channel
  }
  
  proc getreply {} {
    variable channel
    while {true} {
      gets $channel reply
      if {![string equal $reply ""]} {
        break
      }
    }
    log::debug "getreply: reply = \"$reply\"."
    return $reply
  }

  proc sendcommand {command} {
    variable channel
    variable rawposition
    variable rawdescription
    log::debug "sendcommand: sending \"$command\"."
    flush $channel
    puts $channel $command
    switch $command {
      "PO" {
        set reply [getreply]
        log::debug "sendcommand: PO: reply = $reply."
        if {[scan $reply "POSITION: %d" rawposition] != 1} {
          error "unexpected reply \"$reply\" from controller."
        }
        log::debug "sendcommand: PO: rawposition = $rawposition."
      }
      "ID" {
        set reply [getreply]
        set rawdescription $reply
        log::debug "sendcommand: ID: rawdescription = \"$rawdescription\"."
      }
      "GC" {
        set reply [getreply]
        if {![string equal -length 3 $reply "ID:"]} {
          error "unexpected reply: $reply"
        }
        set rawdescription [string range $reply 4 end]
        log::debug "sendcommand: GC: rawdescription = \"$rawdescription\"."
        set reply [getreply]
        if {[scan $reply "SP: %d" speed] != 1} {
          error "unexpected reply: $reply"
        }
        set reply [getreply]
        if {[scan $reply "POSITION: %d" rawposition] != 1} {
          error "unexpected reply \"$reply\" from controller."
        }
        log::debug "sendcommand: GC: rawposition = $rawposition."
      }
    }
    set reply [getreply]
    if {![string equal $reply "OK: $command"]} {
      flush $channel
      error "unexpected reply: $reply"
    }
  }
  
  proc focuserrawupdateposition {} {
    sendcommand "PO"
    return "ok"
  }
  
  proc focuserrawgetposition {} {
    variable rawposition
    return $rawposition
  }
  
  proc focuserrawsetposition {newposition} {
    log::debug "focuserrawsetposition: starting."
    if {$newposition < [focuserrawgetminposition] || $newposition > [focuserrawgetmaxposition]} {
      return "invalid position"
    }
    sendcommand "AB"
    sendcommand [format "ST %d" $newposition]
    sendcommand "PO"
    log::debug "focuserrawsetposition: done."
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
    sendcommand "AB"
    sendcommand [format "MA %d" $newposition]
    log::debug "focuserrawmove: done."
    return "ok"
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "focuser.tcl"]
