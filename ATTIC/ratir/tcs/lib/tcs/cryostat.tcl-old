########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2013, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "log"
package require "utcclock"

package provide "cryostat" 0.0

namespace eval "cryostat" {

  ######################################################################

  set server::datalifeseconds 120

  ######################################################################
  
  variable maxsafeA             50
  variable maxreliableA         310
  variable alarmdelay           300
  
  ######################################################################
  
  server::setdata "alarm" "ok"
  
  ######################################################################
  
  proc formattemperature {temperature} {
    if {[string is double -strict $temperature]} {
      return [format "%.3f K" $temperature]
    } else {
      return $temperature
    }
  }
  
  proc trend {value lastvalue lasttrend} {
    if {[string equal $lastvalue "unknown"]} {
      return "unknown"
    } elseif {$lastvalue < $value} {
      return "rising"
    } elseif {$lastvalue > $value} {
      return "falling"
    } else {
      return $lasttrend
    }
  }

  ######################################################################
  
  proc getmounts {} {
    set mounts {}
    catch {
      set channel [open "/proc/mounts" "r"]
      while {[gets $channel line] > 0} {
        set mount [lindex $line 1]
        lappend mounts $mount
      }
      close $channel
    }
    log::debug "mounts are: \"$mounts\"."
    return $mounts
  }
  
  proc getdirectoryname {} {
    return "/var/cryostat"
  }

  proc getfilename {} {
    set filenames [glob -nocomplain -directory [getdirectoryname] "*"]
    set filemtimesandnames {}
    foreach filename $filenames {
      lappend filemtimesandnames [list [file mtime $filename] $filename]
    }
    set filemtimesandnames [lsort -decreasing -integer -index 0 $filemtimesandnames]
    set filemtimeandname [lindex $filemtimesandnames 0]
    set filename [lindex $filemtimeandname 1]
    return $filename
  }

  proc updatedata {} {
  
    log::debug "updating data."
  
    set A                        "unknown"
    set B                        "unknown"
    set C1                       "unknown"
    set C2                       "unknown"
    set C3                       "unknown"
    set C4                       "unknown"
    set D1                       "unknown"
    set D2                       "unknown"
    set D3                       "unknown"
    set D4                       "unknown"
    set lastA                    "unknown"
    set lastB                    "unknown"
    set lastC1                   "unknown"
    set lastC2                   "unknown"
    set lastC3                   "unknown"
    set lastC4                   "unknown"
    set lastD1                   "unknown"
    set lastD2                   "unknown"
    set lastD3                   "unknown"
    set lastD4                   "unknown"
    set lastP                    "unknown"
    set Atrend                   "unknown"
    set Btrend                   "unknown"
    set C1trend                  "unknown"
    set C2trend                  "unknown"
    set C3trend                  "unknown"
    set C4trend                  "unknown"
    set D1trend                  "unknown"
    set D2trend                  "unknown"
    set D3trend                  "unknown"
    set D4trend                  "unknown"
    set Ptrend                   "unknown"

    set directoryname [getdirectoryname]
    if {[lsearch -exact [getmounts] $directoryname] == -1} {
      log::debug "mounting \"$directoryname\"."
      if {[catch {exec "/bin/mount" $directoryname}]} {
        error "unable to mount \"$directoryname\"."
      }
    }
    
    set filename [getfilename]
    log::debug "log file is \"$filename\"."
    if {[catch {set channel [open $filename]}]} {
      error "unable to open \"$filename\"."
    }
        
    while {true} {

      set line [coroutine::gets $channel]
      if {[eof $channel]} {
        break
      }
    
      if {[scan $line "%s %s %s %f %f %f %f %f %f %f %f %f %f %f %f" \
            date time ampm jd A B C1 C2 C3 C4 D1 D2 D3 D4 P] == 15} {

        set timestampseconds [clock scan "$date $time $ampm" -timezone UTC]
        set timestamp [utcclock::combinedformat $timestampseconds]

        set Atrend        [trend $A  $lastA  $Atrend ]
        set Btrend        [trend $B  $lastB  $Btrend ]
        set C1trend       [trend $C1 $lastC1 $C1trend]
        set C2trend       [trend $C2 $lastC2 $C2trend]
        set C3trend       [trend $C3 $lastC3 $C3trend]
        set C4trend       [trend $C4 $lastC4 $C4trend]
        set D1trend       [trend $D1 $lastD1 $D1trend]
        set D2trend       [trend $D2 $lastD2 $D2trend]
        set D3trend       [trend $D3 $lastD3 $D3trend]
        set D4trend       [trend $D4 $lastD4 $D4trend]
        set Ptrend        [trend $P  $lastP  $Ptrend ]
        
        set lastA        $A
        set lastB        $B
        set lastC1       $C1
        set lastC2       $C2
        set lastC3       $C3
        set lastC4       $C4
        set lastD1       $D1
        set lastD2       $D2
        set lastD3       $D3
        set lastD4       $D4
        set lastP        $P
        
      }

    }
    
    close $channel
    
    variable maxsafeA
    variable maxreliableA
    variable alarmdelay
    
    if {$A > $maxsafeA && $A <= $maxreliableA} {
      set alarm "critical"
      set log log::error
    } elseif {[utcclock::diff now $timestamp] > $alarmdelay} {
      set alarm "warning"
      set log log::warning
    } else {
      set alarm "ok"
      set log log::info
    }
    set lastalarm [server::getdata "alarm"]
    if {![string equal $alarm $lastalarm]} {
      $log "the A temperature is [formattemperature $A] and $Atrend."
    }
    
    server::setdata "timestamp" $timestamp
    server::setdata "alarm"     $alarm
    server::setdata "A"         $A
    server::setdata "B"         $B
    server::setdata "C1"        $C1
    server::setdata "C2"        $C2
    server::setdata "C3"        $C3
    server::setdata "C4"        $C4
    server::setdata "D1"        $D1
    server::setdata "D2"        $D2
    server::setdata "D3"        $D3
    server::setdata "D4"        $D4
    server::setdata "P"         $P
    server::setdata "Atrend"    $Atrend
    server::setdata "Btrend"    $Btrend
    server::setdata "C1trend"   $C1trend
    server::setdata "C2trend"   $C2trend
    server::setdata "C3trend"   $C3trend
    server::setdata "C4trend"   $C4trend
    server::setdata "D1trend"   $D1trend
    server::setdata "D2trend"   $D2trend
    server::setdata "D3trend"   $D3trend
    server::setdata "D4trend"   $D4trend
    server::setdata "Ptrend"    $Ptrend
    
    log::writedatalog "cryostat" {
      timestamp
      alarm
      A Atrend
      B Btrend
      C1 C2trend
      C2 C2trend
      C3 C3trend
      C4 C4trend
      D1 D1trend
      D2 D2trend
      D3 D3trend
      D4 D4trend
      P  Ptrend
    }

  }

  ######################################################################

  variable updatedatapollseconds 15

  proc updatedataloop {} {
    variable updatedatapollseconds
    while {true} {
      if {[catch {updatedata} message]} {
        log::debug "while updating data: $message"
      } else {
        server::setstatus  "ok"
      }
      set updatedatapollmilliseconds [expr {$updatedatapollseconds * 1000}]
      coroutine::after $updatedatapollmilliseconds
    }
  }

  ######################################################################

  proc start {} {
    after idle {
      server::setrequestedactivity "idle"
      server::setactivity          "idle"
      coroutine cryostat::updatedataloopcoroutine cryostat::updatedataloop
    }
  }

}
