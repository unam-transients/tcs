########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "environment"
package require "jsonrpc"
package require "utcclock"
package require "directories"
package require "coroutine"

package provide "log" 0.0

namespace  eval log {

  variable logserverhost [jsonrpc::getserverhost "log"]
  variable logserverport [jsonrpc::getserverport "log"]

  variable logdebug false
  if {[environment::exists "TCSLOGDEBUG"]} {
    set logdebug [environment::get "TCSLOGDEBUG"]
  }
  variable logtostderr false
  if {[environment::exists "TCSLOGTOSTDERR"]} {
    set logtostderr [environment::get "TCSLOGTOSTDERR"]
  }
  variable logtostderronly false
  if {[environment::exists "TCSLOGTOSTDERRONLY"]} {
    set logtostderr [environment::get "TCSLOGTOSTDERRONLY"]
  }
  variable logmarkintervalmilliseconds 60000

  proc fatalerror {message {options {}}} {

    # When reporting a fatal error, we ignore errors in log::puts and
    # always report errors to stderr. Thus, the error message will be
    # output somewhere unless writing to both stderr and the log file
    # fails.

    variable logtostderr
    set logtostderr true

    foreach line [split $message "\n"] {
      catch {log::error "fatal error: $line"}
    }

    if {[dict exists $options -errorinfo]} {
      set errorinfo [dict get $options -errorinfo]
      foreach line [split $errorinfo "\n"] {
        catch {log::error "fatal error: $line"}
      }
    }

    catch {log::error "fatal error: exiting with status 1."}
    exit 1

  }
  
  proc timestamp {} {
    return [utcclock::format now [utcclock::getprecision]]
  }
  
  proc escape {s} {
    return [string map {"\\" "\\\\" "\n" "\\n" "\r" "\\r" "\t" "\\t"} $s]
  }

  proc unescape {s} {
    return [string map {"\\\\" "\\" "\\n" "\n" "\\r" "\r" "\\t" "\t"} $s]
  }
  
  proc error {message {who ""}} {
    putmessage [timestamp] $who "error" $message
  }

  proc warning {message {who ""}} {
    putmessage [timestamp] $who "warning" $message
  }

  proc summary {message {who ""}} {
    putmessage [timestamp] $who "summary" $message
  }

  proc info {message {who ""}} {
    putmessage [timestamp] $who "info" $message
  }

  proc debug {message {who ""}} {
    variable logdebug
    if {$logdebug} {
      putmessage [timestamp] $who "debug" $message
    }
  }

  proc putmessage {timestamp who type message} {

    global argv0
    if {[string equal $who ""]} {
      set who "[file tail $argv0]"
    }
    
    set payload [escape $message]

    variable logtostderr
    variable logtostderronly

    if {$logtostderr || $logtostderronly} {
      catch {
        puts stderr "$timestamp $who: $type: $payload"
        flush stderr
      }
    }
    
    variable islogserver
    variable islogserver
    
    if {!$logtostderronly} {
      if {$islogserver} {
        puttologfiles $timestamp $who $type $payload
      } else {
        puttologsocket $timestamp $who $type $payload
      }
    }
    
  }
  
  proc puttologfiles {timestamp who type payload} {
  
    set logdir [file join [directories::vartoday] "log"]
    if {[catch {file mkdir $logdir} result]} {
      error "while creating directory \"$logdir\": $result"
    }
    
    set line "$timestamp $who: $type: $payload"

    switch -- $type {
      "debug" {
        puttologfile $logdir "debug"        $line
      }
      "info" {
        puttologfile $logdir "info-$who"    $line
        puttologfile $logdir "info"         $line
        puttologfile $logdir "debug"        $line
      }
      "summary" {
        puttologfile $logdir "summary"      $line
        puttologfile $logdir "info-$who"    $line
        puttologfile $logdir "info"         $line
        puttologfile $logdir "debug"        $line
      }
      "warning" {
        puttologfile $logdir "warning"      $line
        puttologfile $logdir "summary"      $line
        puttologfile $logdir "info-$who"    $line
        puttologfile $logdir "info"         $line
        puttologfile $logdir "debug"        $line
      }
      "error" {
        puttologfile $logdir "error"        $line
        puttologfile $logdir "warning"      $line
        puttologfile $logdir "summary"      $line
        puttologfile $logdir "info-$who"    $line
        puttologfile $logdir "info"         $line
        puttologfile $logdir "debug"        $line
      }
      "data" {
        puttodatafile $logdir $who [unescape $payload]
      }
      "keys" {
        puttokeysfile $logdir $who [unescape $payload]
      }
      default {
        error "invalid type argument \"$type\" (in \"$line\")."
      }
    }
  }
  
  variable currentdebuglogfile ""
  variable currentdebuglogchannel ""
  
  proc puttologfile {logdir type line} {
    set logfile [file join $logdir "${type}.txt"]
    set channel [open $logfile a 0666]
    chan configure $channel -blocking false -encoding "utf-8"
    puts $channel $line
    close $channel
  }

  proc puttodatafile {logdir who line} {

    set logfile [file join $logdir "$who-data.txt"]
    set channel [open $logfile a 0666]
    chan configure $channel -blocking false -encoding "utf-8"
    puts $channel $line
    close $channel
    
  }

  proc puttokeysfile {logdir who line} {

    set logfile [file join $logdir "$who-keys.txt"]
    set channel [open $logfile w 0666]
    chan configure $channel -blocking false -encoding "utf-8"
    puts $channel $line
    close $channel
    
  }

  proc mark {} {
    log::debug "- mark -"
  }
  
  ######################################################################

  variable islogserver false
  
  proc openlogserverchannel {} {
    variable logserverhost  
    variable logserverport
    set channel [socket $logserverhost $logserverport]
    chan configure $channel -blocking false -encoding utf-8 -buffering "line"
    return $channel
  }

  variable logserverchannel ""
  
  proc puttologsocket {timestamp who type payload} {
    variable logserverchannel
    set line [join [list $timestamp $who $type $payload] "\t"]
    set notification [jsonrpc::notification "log" [dict create "timestamp" [utcclock::format $timestamp 3 false] "who" $who "type" $type "payload" $payload]]
    set notificationstring [jsonrpc::notificationstring $notification]
    if {[string equal "" $logserverchannel]} {
      set logserverchannel [openlogserverchannel]
    }
    if {[catch {puts $logserverchannel $notificationstring}]} {
      catch {close $logserverchannel}
      set logserverchannel [openlogserverchannel]
      catch {puts $logserverchannel $notificationstring}
    }
  }
  
  proc accept {channel host port} {
    chan configure $channel -blocking false -encoding utf-8 -buffering "line"
    fileevent $channel readable [list log::handleline $channel]
  }
  
  proc handleline {channel} {
    set notificationstring [gets $channel]
    if {[eof $channel]} {
      close $channel
    } elseif {![string equal $notificationstring ""]} {
      set notification [jsonrpc::parsenotification $notificationstring]
      set method [jsonrpc::getmethod $notification]
      set params [jsonrpc::getparams $notification]
      if {![string equal $method "log"]} {
        log::debug "invalid notification: invalid method in \"$notificationstring\"."
      } elseif {
        ![dict exists $params "who"] &&
        ![dict exists $params "type"] &&
        ![dict exists $params "payload"]
      } {
        log::debug "invalid notification: invalid params in \"$notificationstring\"."
      } elseif {
        [catch {utcclock::scan [dict get $params "timestamp"]}]
      } {
        log::debug "invalid notification: invalid timestamp in \"$notificationstring\"."
      } else {
        set timestamp [utcclock::format [dict get $params "timestamp"]]
        set who       [dict get $params "who"]
        set type      [dict get $params "type"]
        set payload   [dict get $params "payload"]
        puttologfiles $timestamp $who $type $payload
      }
    }
  }
  
  proc startlogserver {} {
    variable islogserver
    set islogserver true
    variable logserverport
    log::info "starting."
    socket -server log::accept $logserverport
    log::debug "listening on port $logserverport."
    vwait forever
  }

  ######################################################################

  variable lastdatalogseconds ""

  proc writedatalog {component keys} {
  
    set fullkeys {}
    foreach key $keys {
      if {[catch {server::getdata "${key}-timestamp"}]} {
        lappend fullkeys $key
      } else {
        lappend fullkeys "${key}-timestamp" $key
      }
    }
  
    variable lastdatalogseconds
    set seconds [utcclock::seconds]
    if {![string equal $lastdatalogseconds ""] && ($seconds - $lastdatalogseconds) < 60} {
      return
    }
    set lastdatalogseconds $seconds

    putmessage [timestamp] $component "keys" [join $fullkeys "\t"]

    set data {}
    foreach key $fullkeys {
      set value [server::getdata $key]
      if {[string equal $value ""]} {
        set value "-"
      }
      lappend data $value
    }
    putmessage [timestamp] $component "data" [join $data "\t"]    

  }
  
  ######################################################################
  
  proc writesensorsfile {name value {timestamp "now"}} {
    log::debug "writing sensors file for $name with value \"$value\" and timestamp \"$timestamp\"."
    set sensorsdirectory [file join [directories::var] "sensors" "local"]
    if {[catch {
      file mkdir $sensorsdirectory
    } message]} {
      log::warning "error: while making sensors directory: $message"
      return
    }
    set filename [file join $sensorsdirectory "$name"]
    set tmpfilename "${filename}-tmp"
    if {[catch {
      set channel [open $tmpfilename "w"]
      puts $channel $value
      close $channel
      set seconds [expr {wide([utcclock::scan $timestamp] - [utcclock::scan "1970-01-01T00:00:00"])}]
      file mtime $tmpfilename $seconds
      file rename -force $tmpfilename $filename
    } message]} {
      log::warning "error: while writing sensors file: $message"
      catch {close $channel}
      file delete force $tmpfilename
      return
    }
  }
  
  ######################################################################
  
  after idle {
    coroutine::afterandevery $log::logmarkintervalmilliseconds catch log::mark
  }
}
