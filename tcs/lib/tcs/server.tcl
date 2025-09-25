########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "config"
package require "log"

package require "coroutine"
package require "fromjson"
package require "stack"
package require "utcclock"
package require "version"

package require "jsonrpc"

package provide "server" 0.0

if {[catch {info coroutine}]} {
  log::fatalerror "error: this Tcl does not have coroutines."
}

namespace eval "server" {

  ######################################################################

  proc getservername {} {
    global argv0
    set servername [file tail $argv0]
    if {[string match "?*server" $servername]} {
      set servername [string range $servername 0 end-6]
    }
    return $servername
  }

  ######################################################################

  variable data [dict create \
    pid            [pid] \
    starttimestamp [utcclock::combinedformat now] \
  ]

  proc getdata {key} {
    variable data
    dict get $data $key
  }

  proc setdata {key value} {
    variable data
    dict set data $key $value
  }

  proc getdatadict {} {
    variable data
    return $data
  }

  ######################################################################

  variable datalifeseconds

  setdata status          "starting"
  setdata statustimestamp [utcclock::combinedformat now]

  proc setstatus {status} {
    if {![string equal $status [server::getdata "status"]]} {
      setdata "status" $status
      setdata "statustimestamp" [utcclock::combinedformat now]
    }
  }

  proc getstatus {} {
    variable datalifeseconds
    if {[string equal [getdata status] "ok"]} {
      if {$datalifeseconds > 0} {
        set dataageseconds [utcclock::diff now [getdata timestamp]]
        set activity [server::getdata "activity"]
        if {
          ![string equal $activity "suspended"] &&
          ![string equal $activity "resuming" ] &&
          $datalifeseconds > 0 &&
          $dataageseconds > $datalifeseconds
        } {
          setdata status "stale"
        }
      }
    }
    getdata status
  }

  ######################################################################

  setdata activity                   "starting"
  setdata activitytimestamp          [utcclock::combinedformat now]

  setdata requestedactivity          "unknown"
  setdata requestedactivitytimestamp [utcclock::combinedformat now]

  variable stoppedactivity "started"

  proc setactivity {activity} {
    if {![string equal $activity [server::getactivity]]} {
      log::debug "setting activity to \"$activity\"."
      setdata "activity" $activity
      setdata "activitytimestamp" [utcclock::combinedformat now]
      if {
        [string equal $activity "idle"] ||
        [string equal $activity "suspended"]
      } {
        variable stoppedactivity
        set stoppedactivity $activity
      }
    }
  }

  proc getactivity {} {
    return [server::getdata "activity"]
  }

  proc setrequestedactivity {activity} {
    setdata requestedactivity $activity
    setdata requestedactivitytimestamp [utcclock::combinedformat now]
  }

  proc getrequestedactivity {} {
    return [server::getdata "requestedactivity"]
  }

  proc getstoppedactivity {} {
    variable stoppedactivity
    return $stoppedactivity
  }

  ######################################################################

  proc checkstatus {} {
    if {![string equal [server::getstatus] "ok"]} {
      error "the [getservername] status is \"[server::getstatus]\"."
    }
  }

  proc checkactivity {args} {
    if {[lsearch -exact $args [server::getactivity]] == -1} {
      error "the [getservername] activity is \"[server::getactivity]\"."
    }
  }

  proc checkactivitynot {args} {
    if {[lsearch -exact $args [server::getactivity]] != -1} {
      error "the [getservername] activity is \"[server::getactivity]\"."
    }
  }

  proc checkactivityforinitialize {} {
    checkactivitynot \
      "starting" \
      "error"
  }

  proc checkactivityforswitch {} {
    checkactivity \
      "started" \
      "idle" \
      "error"
  }

  proc checkactivityforreset {} {
    checkactivitynot \
      "starting"
  }

  proc checkactivityforstop {} {
    checkactivitynot \
      "starting" \
      "error"
  }

  proc checkactivityformove {} {
    checkactivitynot \
      "starting" "started" \
      "initializing" \
      "error"
  }

  ######################################################################

  setdata "timedout" "false"

  variable activitystartmilliseconds
  variable activitytimeoutmilliseconds false

  proc setactivitytimeout {timeoutmilliseconds} {
    if {$timeoutmilliseconds != false} {
      log::debug [format "setting activity timeout of %.0f ms." $timeoutmilliseconds]
    }
    variable activitystartmilliseconds
    variable activitytimeoutmilliseconds
    set activitystartmilliseconds [clock milliseconds]
    set activitytimeoutmilliseconds $timeoutmilliseconds
    setdata "timedout" "false"
  }

  proc clearactivitytimeout {} {
    variable activitystartmilliseconds
    variable activitytimeoutmilliseconds
    set activitytimeoutmilliseconds false
    log::debug [format "activity timeout cleared after %.0f ms." [expr {[clock milliseconds] - $activitystartmilliseconds}]]
  }

  proc activitytimeoutloop {} {
    variable activitystartmilliseconds
    variable activitytimeoutmilliseconds
    while {true} {
      if {$activitytimeoutmilliseconds != false && [clock milliseconds] > $activitystartmilliseconds + $activitytimeoutmilliseconds} {
        log::debug [format "activity timeout exceeded after %.0f ms." [expr {[clock milliseconds] - $activitystartmilliseconds}]]
        newactivitycommand [getactivity] [getrequestedactivity] {
          setdata "timedout" "true"
          error "activity timed out."
        }
      }
      coroutine::after 1000
    }
  }

  proc activitytime {} {
    variable activitystartmilliseconds
    return [expr {([clock milliseconds] - $activitystartmilliseconds) / 1000}]
  }

  ######################################################################

  proc resumeactivitycommand {} {
    ::server::activitycommandcoroutine
  }

  proc activitycommandwrapper {activity requestedactivity activitycommand timeoutmilliseconds} {
    setactivity $activity
    setrequestedactivity $requestedactivity
    setactivitytimeout $timeoutmilliseconds
    if {[catch {eval $activitycommand} message]} {
      log::error "while [getactivity]: $message"
      setactivity "error"
      clearactivitytimeout
    } else {
      setactivity [getrequestedactivity]
      clearactivitytimeout
    }
    while {true} {
      ::coroutine::yield
    }
  }

  proc newactivitycommand {activity requestedactivity activitycommand {timeoutmilliseconds 300e3}} {
    coroutine ::server::activitycommandcoroutine \
      server::activitycommandwrapper $activity $requestedactivity $activitycommand $timeoutmilliseconds
  }

  proc erroractivity {} {
    newactivitycommand "signallingerror" "error" {}
  }

  newactivitycommand "starting" "starting" {}

  ######################################################################

  proc handlestatus {} {
    getstatus
    return [getdatadict]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc handleinitialize {} {
    checkstatus
    checkactivityforinitialize
    newactivitycommand "stopping" [server::getstoppedactivity] server::stopactivitycommand
    return
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc handlestop {} {
    checkstatus
    checkactivityforstop
    newactivitycommand "stopping" [server::getstoppedactivity] server::stopactivitycommand
    return
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc handlereset {} {
    checkstatus
    checkactivityforreset
    newactivitycommand "resetting" [server::getstoppedactivity] server::resetactivitycommand
    return
  }

  proc forceerroractivitycommand {} {
    set start [utcclock::seconds]
    log::info "forcing error."
    error "forced by forceerror request."
    set end [utcclock::seconds]
    log::info [format "finished forcing error after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc handleforceerror {} {
    checkstatus
    newactivitycommand "forcingerror" "idle" server::forceerroractivitycommand
    return
  }

  proc handlepushstatus {server status} {
    set statusdict [fromjson::parse $status]
    client::pushstatus $server $statusdict
    return
  }

  ######################################################################

  variable name [dict create]

  proc setname {channel} {
    set host [lindex [chan configure $channel -peername] 0]
    set port [lindex [chan configure $channel -peername] 2]
    variable name
    dict set name $channel "$host:$port"
  }

  proc getname {channel} {
    variable name
    dict get $name $channel
  }

  proc unsetname {channel} {
    variable name
    dict unset name $channel
  }

  variable slave [dict create]
  variable configureslave

  proc createslave {channel} {
    variable slave
    dict set slave $channel [interp create -safe]
    interp alias [getslave $channel] status     {} server::handlestatus
    interp alias [getslave $channel] reset      {} server::handlereset
    interp alias [getslave $channel] forceerror {} server::handleforceerror
    interp alias [getslave $channel] pushstatus {} server::handlepushstatus
    variable configureslave
    $configureslave [getslave $channel]
  }

  proc getslave {channel} {
    variable slave
    dict get $slave $channel
  }

  proc deleteslave {channel} {
    interp delete [getslave $channel]
    variable slave
    dict unset slave $channel
  }
  
  proc handle {channel} {
    if {[catch {
      gets $channel requeststring
      if {[eof $channel]} {
        log::debug "[getname $channel]: closing connection."
        deleteslave $channel
        close $channel
        unsetname $channel
      } elseif {![chan blocked $channel]} {
        log::debug "[getname $channel]: received request \"$requeststring\""
        if {![catch {set request [jsonrpc::parserequest $requeststring]} response]} {
          set command [concat [list [jsonrpc::getmethod $request]] [jsonrpc::getparams $request]]
          log::debug "[getname $channel]: command is \"$command\"."
          if {[catch {interp eval [getslave $channel] $command} result]} {
            log::warning "error while handling command \"$command\": $result"
            set response [jsonrpc::errorresponse $request "-32000" $result]
          } else {
            set response [jsonrpc::response $request $result]
          }
        }
        set responsestring [jsonrpc::responsestring $response]
        log::debug "[getname $channel]: sending response \"$responsestring\"."
        puts $channel $responsestring
      }
    } message]} {
      log::warning "[getname $channel]: error while handling request: $message"
      deleteslave $channel
      close $channel
      unsetname $channel
    }
    return
  }

  proc accept {channel host port} {
    setname $channel
    log::debug "[getname $channel]: accepting connection."
    chan configure $channel -encoding "utf-8"
    chan configure $channel -buffering "line"
    chan configure $channel -translation "auto lf"
    chan configure $channel -blocking false
    createslave $channel
    chan event $channel readable "server::handle $channel"
  }

  proc bgerror {message options} {
    # The message argument seems to be always repeated in the errorinfo
    # entry in $options. Therefore, we override it with something
    # slightly less redundant.
    log::fatalerror "background error." $options
  }

  proc listen {servername configureslavearg} {
    interp bgerror {} server::bgerror
    variable configureslave
    set host [jsonrpc::getserverhost $servername]
    set port [jsonrpc::getserverport $servername]
    set configureslave $configureslavearg
    log::debug "listening on $host:$port."
    socket -server server::accept -myaddr $host $port
  }
  
  proc withserver {servername} {
    if {[catch {jsonrpc::getserverhost $servername}]} {
      return false
    } else {
      return true
    }
  }

  proc start {script} {
    if {[catch {
      log::info "starting server."
      log::info "version is \"[version::version]\"."
      server::setdata "version" [version::version]
      log::debug "executable is \"[info nameofexecutable]\"."
      log::debug "patch level is \"[info patchlevel]\"."
      log::debug "prefix is \"[directories::prefix]\"."
      log::debug "changing working directory to \"[directories::prefix]\"."
      cd [directories::prefix]
      log::debug "current working directory is \"[pwd]\"."
      global argv0
      log::debug "argv0 is \"$argv0\"."
      log::debug "normalized argv0 is \"[file normalize $argv0]\"."
      global argv
      log::debug "argv is \"$argv\"."
      coroutine ::server::activitytimeoutloopcoroutine server::activitytimeoutloop
      log::debug "running script."
      eval $script
      coroutine::start
    } message options]} {
      log::fatalerror $message $options
    }
  }

}
