########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2011, 2012, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "coroutine"

package provide "power" 0.0
  
namespace eval "power" {

  ######################################################################

  variable hosts                [config::getvalue "power" "hosts"]
  variable outletgroupaddresses [config::getvalue "power" "outletgroupaddresses"]

  ######################################################################
  
  set server::datalifeseconds 60

  ######################################################################

  proc gethosts {} {
    variable hosts
    return [dict keys $hosts]
  }
  
  proc gethosttype {host} {
    variable hosts
    return [dict get $hosts $host "type"]
  }
  
  proc gethostoutlets {host} {
    variable hosts
    return [dict get $hosts $host "outlets"]
  }
  
  proc gethostinlets {host} {
    variable hosts
    return [dict get $hosts $host "inlets"]
  }
  
  ######################################################################

  variable outletstatedict {}

  proc getoutletstate {address} {
    variable outletstatedict
    return [dict get $outletstatedict $address]
  }
  
  proc setoutletstate {address state} {
    variable outletstatedict
    dict set outletstatedict $address $state
    return
  }
  
  ######################################################################

  proc getoutletgroups {} {
    variable outletgroupaddresses
    return [dict keys $outletgroupaddresses]
  }
    
  proc getoutletgroupaddresses {outletgroup} {
    variable outletgroupaddresses
    return [dict get $outletgroupaddresses $outletgroup]
  }
  
  proc checkoutletgroup {outletgroup} {
    variable outletgroupaddresses
    if {![dict exists $outletgroupaddresses $outletgroup]} {
      error "invalid outlet group \"$outletgroup\"."
    }
  }
  
  ######################################################################
    
  proc getoutletgroupstate {group} {
    set result {}
    foreach address [getoutletgroupaddresses $group] {
      lappend result [getoutletstate $address]
    }
    return $result
  }
  
  proc outletgroupstateisall {outletgroup state} {
    if {[lsearch -not [getoutletgroupstate $outletgroup] $state] == -1} {
      return true
    } else {
      return false
    }
  }
  
  ######################################################################
  
  proc setoutletgroup {outletgroup state} {
  
    log::info "switching $outletgroup $state."

    switch $state {
      "off" {
        set letterstate  "f"
        set numericstate 0
      }
      "on" {
        set letterstate  "n"
        set numericstate 1
      }
      "cycle" {
        set letterstate "c"
        set numericstate 2
      }
      default {
        error "invalid outlet state \"$state\"."
      }
    }
    
    set addresses [getoutletgroupaddresses $outletgroup]

    set host [lindex [lindex $addresses 0] 0]
    set type [gethosttype $host] 

    switch $type {
      "iboot" {
        set command "printf \"\\\\ePASS\\\\e$letterstate\\\\r\" | nc -w 5 \"$host\" 80"
      }
      "ibootbar" {
        set command "/usr/bin/snmpset -L n -v 1 -c private -M \"+[directories::share]/mibs/\" -m +IBOOTBAR-MIB \"$host\""
        foreach address $addresses {
          if {![string equal $host [lindex $address 0]]} {
            error "mixed hosts in addresses argument to setoutlets."
          }
          set device [lindex $address 1]
          set number [lindex $address 2]
          set j [string first $device "abcdefghijklmnop"]
          set i [expr {8 * $j + $number - 1}]
          set command "$command outletCommand.$i = $numericstate"
        }
      }
      "ibootpdu" {
        set command "/usr/bin/snmpset -L n -v 1 -c private -M \"+[directories::share]/mibs/\" -m +IBOOTPDU-MIB \"$host\""
        foreach address $addresses {
          if {![string equal $host [lindex $address 0]]} {
            error "mixed hosts in addresses argument to setoutlets."
          }
          set device [lindex $address 1]
          set number [lindex $address 2]
          set j [string first $device "abcdefghijklmnop"]
          set i [expr {8 * $j + $number - 1}]
          set command "$command outletControl.$i = $numericstate"
        }
      }
    }

        
    while {true} {
      log::debug "$host: switching $outletgroup."
      log::debug "$host: command = \"$command\"."
      set channel [open "|$command </dev/null 2>@1" "r"]  
      if {[catch {
        chan configure $channel -blocking false
        chan configure $channel -buffering "line"
        chan configure $channel -encoding "ascii"
        while {true} {
          set line [coroutine::gets $channel]
          log::debug "$host: line = \"$line\"."
          if {[chan eof $channel]} {
            break
          } 
          switch $type {
            "ibootbar" {
              if {![string match "IBOOTBAR-MIB::outletCommand.*" $line]} {
                error "snmpset failed: $line"
              }
            }
            "ibootpdu" {
              if {![string match "IBOOTPDU-MIB::outletControl.*" $line]} {
                error "snmpset failed: $line"
              }
            }
          }
        }
      } message]} {
        log::error $message
      }
      close $channel
      coroutine::after 1000
      while {[catch {updatehosts} message]} {
        log::error $message
        coroutine::after 1000
      }
      log::debug "checking $outletgroup: [getoutletgroupstate $outletgroup]."
      if {[outletgroupstateisall $outletgroup $state]} {
        break
      }
      coroutine::after 1000
    }
    
    log::info "finished switching $outletgroup $state."
  }

  ######################################################################
  
  proc updatehost {host} {
    
    log::debug "$host: attempting to update."
    
    set type    [gethosttype $host]
    set outlets [gethostoutlets $host]
    set inlets  [gethostinlets $host]

    switch $type {
      "iboot" {
        set command "printf \"\\\\ePASS\\\\eq\\\\r\" | nc -w 5 \"$host\" 80"
      }
      "ibootbar" {
        set command "/usr/bin/snmpget -L n -v 1 -c public -M \"+[directories::share]/mibs/\" -m +IBOOTBAR-MIB \"$host\""
        for {set i 0} {$i < $outlets} {incr i} {
          set command "$command outletStatus.$i"
        }
        set inlets [gethostinlets $host]
        for {set i 1} {$i <= $inlets} {incr i} {
          set command "$command currentLC$i.0"
        }
      }
      "ibootpdu" {
        set command "/usr/bin/snmpget -L n -v 1 -c public -M \"+[directories::share]/mibs/\" -m +IBOOTPDU-MIB \"$host\""
        for {set i 0} {$i < $outlets} {incr i} {
          set command "$command outletStatus.$i"
        }
        for {set i 1} {$i <= $inlets} {incr i} {
          set command "$command currentLC$i.0"
        }
      }
      default {
        error "unknown power unit type \"$type\"."
      }
    }
    log::debug "$host: command = \"$command\"."
    set channel [open "|$command </dev/null 2>@1" "r"]
    set totalcurrent 0
    if {[catch {
      chan configure $channel -blocking false
      chan configure $channel -buffering "line"
      chan configure $channel -encoding "ascii"
      while {true} {
        set line [coroutine::gets $channel]
        log::debug "$host: line = \"$line\"."
        if {[string equal $line ""] && [chan eof $channel]} {
          break
        } else {
          switch $type {
            "iboot" {
              if {[string equal $line "ON"]} {
                set state "on"
              } elseif {[string equal $line "OFF"]} {
                set state "off"
              } elseif {[string equal $line "CYCLE"]} {
                set state "switching"
              }
              set device "a"
              set number 0
              set address [list $host $device $number]
              log::debug "address = $address state = $state."
              setoutletstate $address $state
            }
            "ibootbar" -
            "ibootpdu" {
              if {[scan $line "%*\[^:\]::outletStatus.%d = INTEGER: %\[^(\](%*d)" outlet state] == 2} {
                if {![string equal $state "on"] && ![string equal $state "off"]} {
                  set state "switching"
                }
                set device [string index "abcdefghijklmnop" [expr {$outlet / 8}]]
                set number [expr {$outlet % 8 + 1}]
                set address [list $host $device $number]
                log::debug "outlet = $outlet address = $address state = $state."
                setoutletstate $address $state
              } elseif {[scan $line "%*\[^:\]::currentLC%d.0 = INTEGER: %d" inlet current] == 2} {
                log::debug "inlet = $inlet current = $current."
                if {[string equal $type "ibootbar"]} {
                  set current [expr {0.1 * $current}]
                } elseif {[string equal $type "ibootpdu"]} {
                  set current [expr {0.01 * $current}]
                }
                set totalcurrent [expr {$totalcurrent + $current}]
              } else {
                error "unexpected SNMP response: $line"
              }
            }
          }
        }
      }
    } message]} {
      log::debug "$host: unable to update: $message"
    } else {
      log::debug "$host: successfully updated."
    }
    switch $type {
      "iboot" {
        server::setdata "$host-current" ""
      }
      "ibootbar" -
      "ibootpdu" {
        server::setdata "$host-current" [format "%.1f" $totalcurrent]
      }
    }
    
    close $channel
  }

  proc updatehosts {} {
    log::debug "updating hosts."
    foreach host [gethosts] {
      if {[catch {updatehost $host} result]} {
        error "unable to update $host: $result"
      }
    }
    if {[string equal "starting" [server::getstatus]]} {
      server::setactivity "idle"
    }
    foreach outletgroup [getoutletgroups] {
      server::setdata $outletgroup [getoutletgroupstate $outletgroup]
    }
    server::setdata "timestamp" [utcclock::combinedformat]
    server::setstatus "ok"
    foreach host [gethosts] {
      log::writesensorsfile "$host-current" [server::getdata "$host-current"] [server::getdata "timestamp"]
    }
    log::debug "finished updating hosts."
  }

  proc updateloop {} {
    while true {
      if {[catch {updatehosts} message]} {
        log::error $message
      }
      coroutine::after 20000
    }
  }
  
  ######################################################################
  
  proc switchonactivitycommand {outletgroup} {
    setoutletgroup $outletgroup "on"
    return
  }

  proc switchoffactivitycommand {outletgroup} {
    setoutletgroup $outletgroup "off"
    return
  }

  proc rebootactivitycommand {outletgroup} {

    # The iBB cycle command is unreliable. When the device is on, about
    # one time in twenty it will power the device off but not on again.
    # Therefore, we explicitly switch the devices off then on again.
    # One disadvantage is that rebooting is no longer atomic.

    switchoffactivitycommand $outletgroup
    switchonactivitycommand $outletgroup
    
    return
  }

  ######################################################################

  proc switchon {outletgroup} {
    server::checkstatus
    server::checkactivity "idle"
    checkoutletgroup $outletgroup
    server::newactivitycommand "switchingon" "idle" "power::switchonactivitycommand $outletgroup"
  }

  proc switchoff {outletgroup} {
    server::checkstatus
    server::checkactivity "idle"
    checkoutletgroup $outletgroup
    server::newactivitycommand "switchingoff" "idle" "power::switchoffactivitycommand $outletgroup"
  }
  
  proc reboot {outletgroup} {
    server::checkstatus
    server::checkactivity "idle"
    checkoutletgroup $outletgroup
    server::newactivitycommand "rebooting" "idle" "power::rebootactivitycommand $outletgroup"
  }
  
  ######################################################################

  proc start {} {
    after idle {
      server::setrequestedactivity "idle"
      server::setactivity          "starting"
      coroutine::create power::updateloop
    }
  }
  
  ######################################################################
  
  proc emergencystop {outletgroup} {
    setoutletgroup $outletgroup "off"
  }

}
