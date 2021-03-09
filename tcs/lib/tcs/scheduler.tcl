########################################################################

# This file is part of the RATTEL telescope control system.

# $Id: scheduler.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package provide "scheduler" 0.0

namespace eval "scheduler" {

  variable svnid {$Id}

  ######################################################################

  variable offsethours [config::getvalue "scheduler" "offsethours"]

  ######################################################################

  variable mode           "disabled"
  variable blockfile      ""
  variable alertfile      ""
  variable alertindex     0

  ######################################################################
  
  proc updatedata {} {
    variable mode
    variable blockfile
    variable alertfile
    server::setdata "mode"             $mode
    server::setdata "blockfile"        $blockfile
    server::setdata "alertfile"        $alertfile
    server::setdata "schedulerdate"    [schedulerdate true]
    server::setdata "focustimestamp"   [constraints::focustimestamp]
    server::setdata "timestamp"        [utcclock::combinedformat now]
  }
  
  ######################################################################

  proc schedulerdate {{extended true}} {
    variable offsethours
    set seconds [expr {[utcclock::seconds] + 3600 * $offsethours}]
    return [utcclock::formatdate $seconds $extended]
  }

  ######################################################################

  proc getalertblockfile {} {
    return [file join [directories::etc] "alertblock"]
  }

  proc getblockfilesdirectory {} {
    log::info "scheduler date is [schedulerdate true]."
    return [file join [directories::var] [schedulerdate false] "blocks"]
  }
  
  proc getblockfiles {} {
    if {[catch {
      set blockfilesdirectory [getblockfilesdirectory]
      set channel [open "|getblockfiles \"$blockfilesdirectory\"" "r"]
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
    variable alertindex
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
    log::debug "unrolled alertfile list is \"$names\"."
    if {$rolled} {
      log::debug "alertindex is $alertindex."
      set n [llength $names]
      if {$n != 0} {
        set names [concat \
          [lrange $names [expr {$alertindex % $n}] end] \
          [lrange $names 0 [expr {$alertindex % $n - 1}]] \
        ]
      }
      log::debug "rolled alertfile list is \"$names\"."
      set alertindex [expr {$alertindex + 1}]
    }
    return $names
  }
  
  ######################################################################
  
  variable block
  
  proc files {blockfile alertfile} {
    if {[string equal $alertfile ""]} {
      return "block file \"[file tail $blockfile]\""
    } else {
      return "block file \"[file tail $blockfile]\" with alert file \"[file tail $alertfile]\""
    }
  }
  
  proc selectable {blockfile alertfile seconds} {
    constraints::start
    if {[catch {
      set block [block::readfile $blockfile]
    } message]} {
      log::warning "error while reading block file \"[file tail $blockfile]\": $message"
      log::warning "deleting block file \"[file tail $blockfile]\"."
      file delete -force $blockfile
      return false
    }
    if {![string equal "" $alertfile] && [catch {
      set block [alert::readfile $alertfile $block]
    } message]} {
      log::warning "error while reading alert file $alertfile: $message"
      return false
    }
    foreach visit [block::visits $block] {
      if {![constraints::check $visit [block::constraints $block] $seconds]} {
        log::info "rejected [files $blockfile $alertfile]: [constraints::why]"
        return false
      }
      set seconds [expr {$seconds + [visit::estimatedduration $visit]}]
    }
    log::info "selected [files $blockfile $alertfile]."
    return true
  }
  
  proc selectalertfile {blockfile seconds} {
    foreach alertfile [getalertfiles true] {
      if {[selectable $blockfile $alertfile $seconds]} {
        return $alertfile
      }
    }
    return ""
  }
    
  proc selectblockfile {seconds} {
    swift::updatefavoredside
    foreach blockfile [getblockfiles] {
      if {[selectable $blockfile "" $seconds]} {
        return $blockfile
      }
    }
    return ""
  }
  
  ######################################################################

  proc blockloop {} {
  
    variable mode
    variable alertfile
    variable blockfile

    log::debug "blockloop: starting."

    set idled false
    set delay 0
    set forcereset false

    server::setstatus "ok" 
    
    while {true} {
    
      set blockfile ""
      set alertfile ""
      updatedata
      server::setrequestedactivity "idle"      

      if {[string equal $mode "disabled"]} {
        log::debug "blockloop: disabled."
        server::setactivity "idle"
        set forcereset false
        coroutine::after 1000
        continue
      }
      
      if {$delay != 0} {
        log::debug "blockloop: waiting for ${delay}ms."
        server::setactivity "waiting"
        coroutine::after $delay
      }
      
      if {[string equal $mode "disabled"]} {
        continue
      }

      if {$forcereset} {
        log::info "resetting."
        server::setactivity "resetting"      
        if {[catch {
          client::request "executor" "reset"
          client::wait "executor"
        } message]} {
          log::error "unable to reset: $message"
          set delay 60000
          set forcereset true
          continue
        }
        set forcereset false
      }
      
      if {[string equal $mode "disabled"]} {
        continue
      }

      log::info "stopping."
      server::setactivity "stopping"      
      if {[catch {
        client::request "executor" "stop"
        client::wait "executor"
      } message]} {
        log::error "unable to stop: $message"
        set forcereset true
        continue
      }

      if {[string equal $mode "disabled"]} {
        continue
      }

      log::info "selecting."
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

      set blockfile [getalertblockfile]
      set alertfile [selectalertfile $blockfile $seconds]
      if {[string equal $alertfile ""]} {
        set blockfile [selectblockfile $seconds]
      }
      updatedata
      
      if {[string equal $mode "disabled"]} {
        continue
      }

      if {[string equal $blockfile ""]} {
        log::info "no block selected."
        if {!$idled} {
          log::info "idling."
          server::setactivity "idling"
          if {[catch {
            client::request "executor" "idle"
            client::wait "executor"
          } message]} {
            log::error "unable to idle: $message"
            set delay 60000
            set forcereset true
            continue
          }
          set idled true
          log::info "finished idling."
        }
        set delay 60000
        continue
      }

      log::info "executing [files $blockfile $alertfile]."
      set block [block::readfile $blockfile]
      log::info "executing block [block::identifier $block] of project [project::identifier [block::project $block]]."
      server::setactivity "executing"
      set idled false
      if {[catch {
        client::request "executor" "execute $blockfile $alertfile"
        client::wait "executor"
      } message]} {
        log::error "unable to execute: $message"
        set delay 60000
        set forcereset true
        continue
      }
      log::info "finished executing [files $blockfile $alertfile]."
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
  
  proc respondtoalert {projectidentifier blockidentifier type eventidentifier alerttimestamp eventtimestamp enabled alpha delta equinox uncertainty} {
    variable mode

    log::summary "responding to alert for $eventidentifier."

    if {![string equal $alerttimestamp ""]} {
      set alerttimestamp [utcclock::combinedformat [utcclock::scan $alerttimestamp]]
    }
    if {![string equal $eventtimestamp ""]} {
      set eventtimestamp [utcclock::combinedformat [utcclock::scan $eventtimestamp]]
    }

    log::info [format "projectidentifier is \"%s\"." $projectidentifier]
    log::info [format "blockidentifier is %s." $blockidentifier]
    log::info [format "type is %s." $type]
    log::info [format "event identifier is %s." $eventidentifier]
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
    if {![string equal $enabled ""]} {
      if {$enabled} {
        log::info "this alert is enabled."
      } else {
        log::info "this alert is not enabled."
      }
    }
    
    set alertfile [getalertfile "$projectidentifier-$blockidentifier"]
    
    file mkdir [file dirname $alertfile]
    log::info [format "alert file is \"%s\"." $alertfile]
    set alertfileexists [file exists $alertfile]

    if {$alertfileexists} {
      set interrupt false
    } elseif {[string equal $enabled ""] || $enabled} {
      set interrupt true
    } else {
      set interrupt false
    }
    set channel [open $alertfile "a"]
    if {!$alertfileexists} {
      puts $channel [format "// Alert file \"%s\"." $alertfile]
      puts $channel [format "// Created at %s." [utcclock::format now]]
    } else {
      puts $channel [format "// Updated at %s." [utcclock::format now]]
    }
    puts $channel [format "\{"]
    puts $channel [format "  \"identifier\": \"%s\"," $blockidentifier]
    puts $channel [format "  \"name\": \"%s\"," $eventidentifier]
    puts $channel [format "  \"project\": \{"]
    puts $channel [format "    \"identifier\": \"%s\"" $projectidentifier]
    puts $channel [format "  \},"]
    puts $channel [format "  \"alert\": \{"]
    puts $channel [format "    \"type\": \"%s\"," $type]
    puts $channel [format "    \"alpha\": \"%s\"," [astrometry::formatalpha $alpha]]
    puts $channel [format "    \"delta\": \"%s\"," [astrometry::formatdelta $delta]]
    puts $channel [format "    \"equinox\": \"%s\"," $equinox]
    puts $channel [format "    \"uncertainty\": \"%s\"," [astrometry::formatdistance $uncertainty]]
    puts $channel [format "    \"eventtimestamp\": \"%s\"," $eventtimestamp]
    puts $channel [format "    \"alerttimestamp\": \"%s\"," $alerttimestamp]
    puts $channel [format "    \"enabled\": \"%s\"" $enabled]
    puts $channel [format "  \}"]
    puts $channel [format "\}"]

    close $channel
    
    if {!$interrupt} {
      log::summary "not interrupting the executor: interrupt is false."
    } elseif {[string equal $mode "disabled"]} {
      log::summary "not interrupting the executor: scheduler is disabled."
#    } elseif {![selectable [getalertblockfile] $alertfile "now"]} {
#      log::summary "not interrupting the executor: alert is not selectable."
    } else {
      log::summary "interrupting the executor."
      if {[catch {client::request "executor" "stop"} message]} {
        log::error "unable to interrupt the executor: $message"
      }
      variable alertindex
      set alertindex 0
    }

    if {!$alertfileexists} {
      log::info "running alertscript."
      if {[catch {
        exec "[directories::etc]/alertscript" $type $eventidentifier $blockidentifier
      } message]} {
        log::warning "alertscript failed: $message."
      }
      log::info "finished running alertscript."
    }

    log::summary "finished responding to alert."
    return
  }
  
  proc respondtolvcalert {projectidentifier blockidentifier type eventidentifier alerttimestamp eventtimestamp enabled skymapurl} {
    log::summary "responding to lvc alert."    
    if {![string equal $skymapurl ""]} {
      log::info [format "skymap url is %s." $skymapurl]
      set channel [open "|newpgrp  lvcskymapfindpeak $skymapurl" "r"]
      chan configure $channel -buffering "line"
      chan configure $channel -encoding "ascii"
      set line [coroutine::gets $channel 0 100]
      catch {close $channel}
      if {[scan $line "%f %f %s" alpha delta equinox] != 3} {
        log::error "lvcskymapfindpeak failed: $line."
        error "lvcskymapfindpeak failed: $line."
      }
      set alpha [astrometry::formatalpha [astrometry::degtorad $alpha]]
      set delta [astrometry::formatdelta [astrometry::degtorad $delta]]
      set uncertainty "10d"
      log::info [format "peak position is %s %s %s." [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
    } else {
      set alpha       ""
      set delta       ""
      set equinox     ""
      set uncertainty ""
    }
    respondtoalert $projectidentifier $blockidentifier $type $eventidentifier $alerttimestamp $eventtimestamp $enabled $alpha $delta $equinox $uncertainty
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
  
  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setstatus "starting"
    server::setactivity "starting"
    server::setrequestedactivity "idle"
    updatedata
    after idle {
      coroutine scheduler::blockloopcoroutine scheduler::blockloop
    }
  }

}
