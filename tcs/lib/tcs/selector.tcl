########################################################################

# This file is part of the RATTEL telescope control system.

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "alert"
package require "block"
package require "config"
package require "client"
package require "constraints"
package require "directories"
package require "log"
package require "project"
package require "server"
package require "visit"

package provide "selector" 0.0

config::setdefaultvalue "selector" "alertprojectidentifier" "1000"
config::setdefaultvalue "selector" "eventtimestamptoleranceseconds" "60"

namespace eval "selector" {

  ######################################################################

  variable alertprojectidentifier         [config::getvalue "selector" "alertprojectidentifier"]
  variable eventtimestamptoleranceseconds [config::getvalue "selector" "eventtimestamptoleranceseconds"]
  variable priorities                     [config::getvalue "selector" "priorities"]

  ######################################################################

  variable mode           "disabled"
  variable filetype       ""
  variable filename       ""
  variable priority       ""
  variable alertrollindex 0

  ######################################################################
  
  proc updatedata {} {
    variable mode
    variable filetype
    variable filename
    variable priority
    server::setdata "mode"             $mode
    server::setdata "filetype"         $filetype
    server::setdata "filename"         $filename
    server::setdata "priority"         $priority
    server::setdata "focustimestamp"   [constraints::focustimestamp]
    server::setdata "timestamp"        [utcclock::combinedformat now]
  }
  
  ######################################################################

  proc sendchat {category message} {
    log::info "sending $category message \"$message\"."
    exec "[directories::prefix]/bin/tcs" "sendchat" "$category" "$message"
  }
  
  ######################################################################

  proc getblockfiles {} {
    if {[catch {
      set channel [open "|[directories::bin]/tcs getblockfiles" "r"]
      set blockfiles [read $channel]
      close $channel
      set blockfiles [split [string trimright $blockfiles "\n"] "\n"]
      log::debug "block files are \"$blockfiles\"."
    } message]} {
      log::error "unable to get block files: $message"
      set blockfiles {}
    }
    return $blockfiles
  }
  
  proc getalertfile {tail} {
    set alertfile [file join [directories::var] "alerts" $tail]
    set oldalertfile [file join [directories::var] "oldalerts" $tail]
    if {[file exists $alertfile]} {
      return $alertfile
    } elseif {[file exists $oldalertfile]} {
      return $oldalertfile
    } else {
      return $alertfile
    }
  }
  
  proc getalertfiles {rolled} {
    variable alertrollindex
    set names [glob -nocomplain -directory [file join [directories::var] "alerts"] "*"]
    set mtimesandnames {}
    foreach name $names {
      lappend mtimesandnames [list [file mtime $name] $name]
    }
    set mtimesandnames [lsort -decreasing -integer -index 0 $mtimesandnames]
    set names {}
    foreach mtimeandname $mtimesandnames {
      set name [lindex $mtimeandname 1]
      lappend names $name
    }
    if {$rolled} {
      log::info "unrolled alertfile list is \"$names\"."
      log::info "alertrollindex is $alertrollindex."
      set n [llength $names]
      if {$n != 0} {
        set names [concat \
          [lrange $names [expr {$alertrollindex % $n}] end] \
          [lrange $names 0 [expr {$alertrollindex % $n - 1}]] \
        ]
      }
      log::info "rolled alertfile list is \"$names\"."
    }
    return $names
  }
  
  ######################################################################
  
  proc isselectableblock {block seconds priority} {
    if {![block::checkpriority $block $priority]} {
      return [block::why]
    } elseif {![constraints::check $block $seconds]} {
      return [constraints::why]
    } else {
      return ""
    }
  }

  proc isselectablealertfile {alertfile seconds priority} {
    if {[catch {
      set block [alert::alerttoblock [alert::readalertfile $alertfile]]
    } message]} {
      log::warning "error while reading alert file \"[file tail $alertfile]\": $message"
      return "invalid alert file."
    } 
    return [isselectableblock $block $seconds $priority]
  }
  
  proc selectalertfile {seconds priority} {
    foreach alertfile [getalertfiles true] {
      log::info "considering alert file \"[file tail $alertfile]\"."
      set why [isselectablealertfile $alertfile $seconds $priority]
      if {[string equal $why ""]} {
        log::summary "selected alert file \"[file tail $alertfile]\"."
        return $alertfile
      }
      log::info "rejected alert file \"[file tail $alertfile]\": $why"
      coroutine::after 1
    }
    return ""
  }
    
  proc isselectableblockfile {blockfile seconds priority} {
    if {[catch {
      set block [block::readfile $blockfile]
    } message]} {
      log::warning "error while reading block file \"[file tail $blockfile]\": $message"
      log::warning "deleting block file \"[file tail $blockfile]\"."
      file delete -force $blockfile
      return "invalid block file."
    }
    return [isselectableblock $block $seconds $priority]
  }
  
  proc selectblockfile {seconds priority} {
    swift::updatefavoredside
    foreach blockfile [getblockfiles] {
      log::info "considering block file \"[file tail $blockfile]\"."
      set why [isselectableblockfile $blockfile $seconds $priority]
      if {[string equal $why ""]} {
        log::summary "selected block file \"[file tail $blockfile]\"."
        return $blockfile
      }
      log::info "rejected block file \"[file tail $blockfile]\": $why"
      coroutine::after 1
    }
    return ""
  }
  
  ######################################################################

  proc getallalertfiles {} {
    set names    [lsort -decreasing [glob -nocomplain -directory [file join [directories::var] "alerts"   ] "*"]]
    set oldnames [lsort -decreasing [glob -nocomplain -directory [file join [directories::var] "oldalerts"] "*"]]
    return [concat $names $oldnames]
  }
  
  proc matchalert {origin originidentifier eventtimestamp alerttimestamp} {
    foreach alertfile [getallalertfiles] {
      if {[catch {
        set alert [alert::readalertfile $alertfile]
      } message]} {
        log::warning "error while reading alert file \"[file tail $alertfile]\": $message"
        continue
      }
      if {[string equal [alert::originidentifier $alert $origin] $originidentifier]} {
        log::info "alert file \"[file tail $alertfile]\" matches by origin identifier."
        return [file tail $alertfile]
      }
      set mineventtimestamp [alert::mineventtimestamp $alert]
      set maxeventtimestamp [alert::maxeventtimestamp $alert]
      if {
        ![string equal $eventtimestamp    ""] &&
        ![string equal $mineventtimestamp ""] &&
        ![string equal $maxeventtimestamp ""]
      } {
        variable eventtimestamptoleranceseconds
        if {
          [utcclock::diff $mineventtimestamp $eventtimestamp] <= $eventtimestamptoleranceseconds && 
          [utcclock::diff $eventtimestamp $maxeventtimestamp] <= $eventtimestamptoleranceseconds
        } {
          log::info "alert file \"[file tail $alertfile]\" matches by event timestamp."
          return [file tail $alertfile]
        }
      }
      log::info "alert file \"[file tail $alertfile]\" is not a match."
    }
    log::info "no existing alert file matches."
    if {[string equal $eventtimestamp ""]} {
      set timestamp $alerttimestamp
    } else {
      set timestamp $eventtimestamp
    }
    set alertfile [string map {"T" ""} [utcclock::combinedformat $timestamp 0 false]]
    set alertfile [file join [file join [directories::var] "alerts"] $alertfile]
    return $alertfile
  }

  proc getalertfilebyidentifier {identifier} {
    foreach alertfile [getallalertfiles] {
      if {[catch {
        set alert [alert::readalertfile $alertfile]
      } message]} {
        log::warning "error while reading alert file \"[file tail $alertfile]\": $message"
        continue
      }
      if {[string equal [alert::identifier $alert] $identifier]} {
        return $alertfile
      }
    }
    return ""
  }

  ######################################################################
  
  proc modifyalertfile {alertfile enabled alpha delta equinox uncertainty maxalertdelay priority} {
    set channel [open $alertfile "a"]
    puts $channel [format "// Modified at %s." [utcclock::format now]]
    puts $channel [format "\{"]
    if {![string equal $alpha ""]} {
      log::info [format "modified position is %s %s %s." [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
      puts $channel [format "  \"alpha\": \"%s\"," [astrometry::formatalpha $alpha]]
      puts $channel [format "  \"delta\": \"%s\"," [astrometry::formatdelta $delta]]
      puts $channel [format "  \"equinox\": \"%s\"," $equinox]
      log::info [format "modified uncertainty is %s." [astrometry::formatdistance $uncertainty]]
      puts $channel [format "  \"uncertainty\": \"%s\"," [astrometry::formatdistance $uncertainty]]
    }
    if {![string equal $maxalertdelay ""]} {
      log::info [format "modified maxalertdelay is %s." $maxalertdelay]
      puts $channel [format "  \"maxalertdelay\": \"%s\"," $maxalertdelay]
    }
    if {![string equal $priority ""]} {
      log::info [format "modified priority is %d." $priority]
      puts $channel [format "  \"priority\": \"%d\"," $priority]
    }
    if {![string equal $enabled ""]} {
      puts $channel [format "  \"enabled\": \"%s\"," $enabled]
    }
    puts $channel [format "  \"lastmodifiedtimestamp\": \"%s\"" [utcclock::combinedformat now]]
    puts $channel [format "\}"]
    close $channel 
  }
  
  ######################################################################

  proc blockloop {} {
  
    variable mode
    variable filetype
    variable filename
    variable priority

    log::debug "blockloop: starting."

    set idled false
    set delay 0

    server::setstatus "ok" 
    
    while {true} {
    
      set filetype ""
      set filename ""
      set priority ""
      updatedata
      server::setrequestedactivity "idle"      

      if {[string equal $mode "disabled"]} {
        log::debug "blockloop: disabled."
        server::setactivity "idle"
        coroutine::after 1000
        continue
      }
      
      if {$delay != 0} {
        log::debug "blockloop: waiting for $delay ms."
        server::setactivity "waiting"
        coroutine::after $delay
      }
      
      if {[string equal $mode "disabled"]} {
        continue
      }

      log::summary "selecting."
      server::setactivity "selecting"
      set seconds [utcclock::seconds]
      if {[string equal "" [constraints::focustimestamp]]} {
        log::info "not focused."
      } else {
        log::info [format "%.0f seconds since last focused." [utcclock::diff $seconds [constraints::focustimestamp]]]
      }

      if {[string equal $mode "disabled"]} {
        continue
      }

      foreach priority {0 1 2 3 4 5 6 7 8 9 10} {
        log::info "checking alert queue for priority $priority alerts."
        set filename [selectalertfile $seconds $priority]
        if {![string equal $filename ""]} {
          set filetype "alert"
          variable alertrollindex
          set alertrollindex [expr {$alertrollindex + 1}]
          break
        }
        log::info "checking block queue for priority $priority blocks."
        set filename [selectblockfile $seconds $priority]
        if {![string equal $filename ""]} {
          set filetype "block"
          break
        }
      }
      updatedata
      
      if {[string equal $mode "disabled"]} {
        continue
      }

      if {[string equal $filename ""]} {
        log::summary "no alert or block selected."
        if {!$idled} {
          log::info "idling."
          server::setactivity "idling"
          if {[catch {
            client::request "executor" "idle"
            client::wait "executor"
          } message]} {
            log::error "unable to idle: $message"
            set delay 60000
            continue
          }
          set idled true
          log::info "finished idling."
        }
        set delay 60000
        continue
      }

      log::summary "executing $filetype file \"[file tail $filename]\"."
      server::setactivity "executing"
      set idled false
      if {[catch {
        client::request "executor" "execute $filetype $filename"
        client::wait "executor"
      } message]} {
        log::error "unable to execute: $message"
        set delay 60000
        continue
      }
      log::summary "finished executing $filetype file \"[file tail $filename]\"."
      set delay 0
    }
  
  }
  
  ######################################################################

  proc stop {} {
    log::summary "stopping."
    server::checkstatus
    server::checkactivityforstop
    server::setactivity [server::getrequestedactivity]
    log::summary "finished stopping."
    return
  }

  proc reset {} {
    log::summary "resetting."
    server::checkstatus
    server::checkactivityforreset
    server::setactivity [server::getrequestedactivity]
    log::summary "finished resetting."
    return
  }
  
  proc enable {} {
    log::summary "enabling."
    variable mode
    set mode "enabled"
    updatedata
    server::setrequestedactivity "idle"
    log::summary "finished enabling."
    return
  }
  
  proc disable {} {
    log::summary "disabling."
    variable mode
    set lastmode $mode
    set mode "disabled"
    updatedata
    if {[string equal $lastmode "enabled"]} {
      log::info "interrupting the executor."
      if {[catch {client::request "executor" "stop"} message]} {
        log::error "unable to interrupt the executor: $message"
      }
    }
    server::setactivity "idle"
    server::setrequestedactivity "idle"
    log::summary "finished disabling."
    return
  }
  
  proc getpriority {type class messengers} {
  
    variable priorities
  
    foreach matcher [dict keys $priorities] {
      if {[string match $matcher "$type-$class-$messengers"]} {
        log::info "event matches \"$matcher\"."
        return [dict get $priorities $matcher]
      }
    }

    return 10
  }
  
  proc respondtoalert {blockidentifier name origin
    originidentifier type alerttimestamp eventtimestamp enabled alpha delta equinox
    uncertainty class messenger
  } {
    variable mode
    
    log::summary "responding to alert for $name."

    if {![string equal $alerttimestamp ""]} {
      set alerttimestamp [utcclock::combinedformat [utcclock::scan $alerttimestamp]]
    }
    if {![string equal $eventtimestamp ""]} {
      set eventtimestamp [utcclock::combinedformat [utcclock::scan $eventtimestamp]]
    }

    log::info [format "blockidentifier is %s." $blockidentifier]
    log::info [format "origin/originidentifier/type are %s/%s/%s." $origin $originidentifier $type]
    log::info [format "alert timestamp is %s." [utcclock::format [utcclock::scan $alerttimestamp]]]
    if {![string equal $eventtimestamp ""]} {
      log::info [format "event timestamp is %s." [utcclock::format [utcclock::scan $eventtimestamp]]]
      log::info [format "event delay is %s." [utcclock::formatinterval [utcclock::diff $alerttimestamp $eventtimestamp]]]
    } else {
      log::info "no event timestamp."
    }
    if {![string equal $alpha ""] && ![string equal $delta ""] && ![string equal $equinox ""] && ![string equal $uncertainty ""]} {
      set alpha [astrometry::parsealpha $alpha]
      set delta [astrometry::parsedelta $delta]
      set equinox [astrometry::parseequinox $equinox]
      set uncertainty [astrometry::parsedistance $uncertainty]
      log::info [format "position is %s %s %s." [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
      log::info [format "uncertainty is %s." [astrometry::formatdistance $uncertainty]]
    }
    log::info [format "class is %s." $class]
    log::info [format "messenger is %s." $messenger]
    if {![string equal $enabled ""]} {
      if {$enabled} {
        log::info "this alert is enabled."
      } else {
        log::info "this alert is not enabled."
      }
    }
    
    set alertfile [matchalert $origin $originidentifier $eventtimestamp $alerttimestamp]
    set fullalertfile [getalertfile $alertfile]
    
    file mkdir [file dirname $fullalertfile]
    log::info [format "alert file is \"%s\"." $alertfile]
    set alertfileexists [file exists $fullalertfile]

    if {$alertfileexists} {
      set alert [alert::readalertfile $fullalertfile]
    } else {
      set alert {}        
    }

    set messengers {}
    if {[alert::messenger $alert "electromagnetic"] || [string equal "electromagnetic" $messenger]} {
      lappend messengers "electromagnetic"
    } else {
      lappend messengers ""
    }
    if {[alert::messenger $alert "gravitational"  ] || [string equal "gravitational"   $messenger]} {
      lappend messengers "gravitational"
    } else {
      lappend messengers ""
    }
    if {[alert::messenger $alert "neutrino"       ] || [string equal "neutrino"        $messenger]} {
      lappend messengers "neutrino"
    } else {
      lappend messengers ""
    }
    set messengers [join $messengers "/"]
    log::info [format "messengers are %s." $messengers]

    set priority [getpriority $type $class $messengers]
    log::info [format "priority is %d." $priority]
    
    set channel [open $fullalertfile "a"]
    if {!$alertfileexists} {
      puts $channel [format "// Alert file \"%s\"." $alertfile]
      puts $channel [format "// Created at %s." [utcclock::format now]]
    } else {
      puts $channel [format "// Updated at %s." [utcclock::format now]]
    }
    puts $channel [format "\{"]
    if {![string equal "" $name]} {
      puts $channel [format "  \"name\": \"%s\"," $name]
    }
    puts $channel [format "  \"origin\": \"%s\"," $origin]
    puts $channel [format "  \"%sidentifier\": \"%s\"," $origin $originidentifier]
    puts $channel [format "  \"type\": \"%s\"," $type]
    variable alertprojectidentifier
    puts $channel [format "  \"projectidentifier\": \"%s\"," $alertprojectidentifier]
    puts $channel [format "  \"identifier\": \"%s\"," [string map {"T" ""} [file tail $alertfile]]]
    puts $channel [format "  \"priority\": %d," $priority]
    if {
      ![string equal "" $alpha] && 
      ![string equal "" $delta] &&
      ![string equal "" $equinox] &&
      ![string equal "" $uncertainty]
    } {
      puts $channel [format "  \"alpha\": \"%s\"," [astrometry::formatalpha $alpha]]
      puts $channel [format "  \"delta\": \"%s\"," [astrometry::formatdelta $delta]]
      puts $channel [format "  \"equinox\": \"%s\"," $equinox]
      puts $channel [format "  \"uncertainty\": \"%s\"," [astrometry::formatdistance $uncertainty]]
    }
    if {![string equal "" $enabled]} {
      puts $channel [format "  \"enabled\": \"%s\"," $enabled]
    }
    if {![string equal "" $eventtimestamp]} {
      puts $channel [format "  \"eventtimestamp\": \"%s\"," $eventtimestamp]
    }
    puts $channel [format "  \"alerttimestamp\": \"%s\"," $alerttimestamp]
    puts $channel [format "  \"%s\": \"true\"" $messenger]
    puts $channel [format "\}"]

    close $channel
    
    if {[string equal $mode "disabled"]} {
      log::summary "not interrupting the executor: selector is disabled."
    } elseif {![string equal "" [server::getdata "priority"]] && ([server::getdata "priority"] < $priority)} {
      log::summary [format "not interrupting the executor: current priority is %d." [server::getdata "priority"]]
    } else {
      set why [isselectablealertfile $fullalertfile [utcclock::seconds] $priority]
      if {![string equal "" $why]} {
        log::summary "not interrupting the executor: alert is not selectable: $why"
      } else {
        log::summary "interrupting the executor."
        if {[catch {client::request "executor" "stop"} message]} {
          log::error "unable to interrupt the executor: $message"
        }
        variable alertrollindex
        set alertrollindex 0
      }
    }
    
    sendchat alerts "block $blockidentifier ($name): received a $type GCN Notice for $originidentifier."
    if {!$alertfileexists && ([string equal "" $enabled] || $enabled)} {
      log::info "running alertscript."
      if {[catch {
        exec "[directories::etc]/alertscript" $name $origin $originidentifier $type
      } message]} {
        log::warning "alertscript failed: $message."
      }
      log::info "finished running alertscript."
    }

    makealertspage

    log::summary "finished responding to alert."
    return
  }
  
  proc respondtolvcalert {blockidentifier name origin
    originidentifier type alerttimestamp eventtimestamp enabled skymapurl class
  } {
    log::summary "responding to lvc alert."    
    if {![string equal $skymapurl ""]} {
      log::info [format "skymap url is %s." $skymapurl]
      set channel [open "|[directories::bin]/tcs newpgrp [directories::bin]/tcs lvcskymapfindpeak $skymapurl" "r"]
      chan configure $channel -buffering "line"
      chan configure $channel -encoding "ascii"
      set line [coroutine::gets $channel 0 100]
      catch {close $channel}
      #if {[scan $line "%f %f %s" alpha delta equinox] != 3} {
      #  log::error "tcs lvcskymapfindpeak failed: $line."
      #  error "tcs lvcskymapfindpeak failed: $line."
      #}
      #set alpha [astrometry::formatalpha [astrometry::degtorad $alpha]]
      #set delta [astrometry::formatdelta [astrometry::degtorad $delta]]
      set alpha 00:00:00
      set delta -90:00:00
      set equinox 2000
      set uncertainty "20d"
      #log::info [format "peak position is %s %s %s." [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
    } else {
      set alpha       ""
      set delta       ""
      set equinox     ""
      set uncertainty ""
    }
    respondtoalert $blockidentifier $name $origin \
      $originidentifier $type $alerttimestamp $eventtimestamp $enabled \
      $alpha $delta $equinox $uncertainty $class "gravitational"
    log::summary "finished responding to lvc alert."
    return
  }
  
  proc setfocused {} {
    log::info "setting focus timestamp."  
    constraints::setfocustimestamp [utcclock::combinedformat]
    updatedata
    log::info "finished setting focus timestamp."  
    return
  }
  
  proc setunfocused {} {
    log::info "unsetting focus timestamp." 
    constraints::setfocustimestamp ""
    updatedata
    log::info "finished unsetting focus timestamp."  
    return
  }
  
  proc refocus {} {
    log::info "requesting refocus."
    setunfocused
    variable mode
    if {[string equal [server::getactivity] "executing"]} {
      client::request "executor" "stop"
    }
    log::info "finished requesting refocus."
    return
  }
  
  proc reselect {} {
    log::info "requesting reselect."
    variable mode
    if {[string equal [server::getactivity] "executing"]} {
      client::request "executor" "stop"
    }
    log::info "finished requesting reselect."
    return
  }
  
  proc makealertspage {} {
    set tmpfilename [file join [directories::var] "alerts.json.[pid]"]
    set channel [open $tmpfilename "w"]
    puts $channel "\["
    set first true
    foreach alertfile [getalertfiles false] {
      if {!$first} {
        puts $channel ","
      }
      puts $channel [tojson::object [alert::readalertfile $alertfile] tojson::string]
      set first false
    }
    puts $channel "\]"
    close $channel
    file rename -force -- $tmpfilename [file join [directories::var] "alerts.json"]
    exec "[directories::prefix]/bin/tcs" "makealertspage"
  }
  
  proc enablealert {identifier} {
    log::info "enabling alert $identifier."
    set alertfile [getalertfilebyidentifier $identifier]
    if {[string equal "" $alertfile]} {
      error "no alert has an identifier of \"$identifier\"."
    }
    log::info "alert file is $alertfile."
    modifyalertfile $alertfile true "" "" "" "" "" ""
    makealertspage
    log::info "finished enabling alert $identifier."
    return
  }
  
  proc disablealert {identifier} {
    log::info "disabling alert $identifier."
    set alertfile [getalertfilebyidentifier $identifier]
    if {[string equal "" $alertfile]} {
      error "no alert has an identifier of \"$identifier\"."
    }
    log::info "alert file is $alertfile."
    modifyalertfile $alertfile false "" "" "" "" "" ""
    makealertspage
    log::info "finished disabling alert $identifier."
    return
  }
  
  proc modifyalert {identifier alpha delta equinox uncertainty maxalertdelay priority} {
    log::info "modifying alert $identifier."
    if {![string equal "" $alpha] && [catch {astrometry::parsealpha $alpha}]} {
      error "invalid alpha value \"$alpha\"."
    }
    if {![string equal "" $delta] && [catch {astrometry::parsedelta $delta}]} {
      error "invalid delta value \"$delta\"."
    }
    if {[catch {astrometry::parseequinox $equinox}]} {
      error "invalid equinox value \"$equinox\"."
    }
    if {![string equal "" $uncertainty] && [catch {astrometry::parsedistance $uncertainty}]} {
      error "invalid uncertainty value \"$uncertainty\"."
    }
    if {![string equal "" $alpha] && [string equal "" $delta]} {
      error "alpha given without delta."
    }
    if {![string equal "" $delta] && [string equal "" $alpha]} {
      error "delta given without alpha."
    }
    if {![string equal "" $alpha] && [string equal "" $uncertainty]} {
      error "position given without uncertainty."
    }
    if {![string equal "" $maxalertdelay] && [catch {utcclock::scaninterval $maxalertdelay}]} {
      error "invalid maxalertdelay value \"$maxalertdelay\"."
    }
    if {![string equal "" $priority] && !([string is integer -strict $priority] && 0 <= $priority && $priority <= 10)} {
      error "invalid priority value \"$priority\"."
    }
    set alertfile [getalertfilebyidentifier $identifier]
    if {[string equal "" $alertfile]} {
      error "no alert has an identifier of \"$identifier\"."
    }
    log::info "alert file is $alertfile."
    modifyalertfile $alertfile "" $alpha $delta $equinox $uncertainty $maxalertdelay $priority
    makealertspage
    log::info "finished modifying alert $identifier."
    return
  }
  
  proc createalert {name eventtimestamp alpha delta equinox uncertainty priority} {
    log::info "creating alert."
    if {[catch {utcclock::scan $eventtimestamp}]} {
      error "invalid event timestamp \"$eventtimestamp\"."
    }
    if {[catch {astrometry::parsealpha $alpha}]} {
      error "invalid alpha value \"$alpha\"."
    }
    if {[catch {astrometry::parsedelta $delta}]} {
      error "invalid delta value \"$delta\"."
    }
    if {[catch {astrometry::parseequinox $equinox}]} {
      error "invalid equinox value \"$equinox\"."
    }
    if {[catch {astrometry::parsedistance $uncertainty}]} {
      error "invalid uncertainty value \"$uncertainty\"."
    }
    if {!([string is integer -strict $priority] && 0 <= $priority && $priority <= 10)} {
      error "invalid priority value \"$priority\"."
    }
    set alerttimestamp [utcclock::combinedformat "now"]
    set eventtimestamp [utcclock::combinedformat [utcclock::scan $eventtimestamp]]
    set identifier     [string map {"T" ""} [utcclock::combinedformat [utcclock::scan $eventtimestamp] 0]]
    respondtoalert $identifier $name "unknown" \
      $alerttimestamp "unknown" $alerttimestamp $eventtimestamp true $alpha $delta $equinox \
      $uncertainty "unknown" "unknown"
    log::info "finished creating alert."
    return
  }

  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setactivity "starting"
    server::setrequestedactivity "idle"
    updatedata
    after idle {
      coroutine selector::blockloopcoroutine selector::blockloop
    }
  }

}
