########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "utcclock"
package require "jsonrpc"

package provide "client" 0.0

namespace eval "client" {

  ########################################################################

  variable connectiontimeout 10000
  variable responsetimeout   10000

  proc rawrequest {server command} {
    set host [jsonrpc::getserverhost $server]
    set port [jsonrpc::getserverport $server]
    set start [clock milliseconds]
    set method [lindex $command 0]
    set params [lrange $command 1 end]
    set request [jsonrpc::request $method $params]
    set requeststring [jsonrpc::requeststring $request]
    while {true} {
      if {![catch {socket $host $port} channel]} {
        break
      }
      variable connectiontimeout
      if {[clock milliseconds] - $start <= $connectiontimeout} {
        continue
      }
      error "connection to $server server refused."
    }
    chan configure $channel -buffering "line"
    chan configure $channel -translation "auto lf"
    chan configure $channel -encoding "utf-8"
    puts $channel "$requeststring"
    variable responsetimeout
    if {[catch {coroutine::gets $channel $responsetimeout} responsestring]} {
      close $channel
      error "no response from $server server to request \"$request\"."
    }
    if {[eof $channel]} {
      close $channel
      error "connection closed unexpectedly by $server server."
    }
    close $channel
    if {[catch {set response [jsonrpc::parseresponse $responsestring]} message]} {
      error "invalid response from $server server: $message"
    } elseif {![jsonrpc::isvalidresponseid $response $request]} {
      error "invalid response from $server server: incorrect id."
    } elseif {[jsonrpc::iserrorresponse $response]} {
      error [jsonrpc::geterrormessage $response]
    } else {
      return [jsonrpc::getresult $response]
    }
  }
  
  ########################################################################
  
  variable statusdicts {}
  
  proc getstatusdict {server} {
    variable statusdicts
    return [dict get $statusdicts $server]
  }

  variable pushservers {
    "gcn"
  }

  proc update {server} {
    variable statusdicts
    variable pushservers
    if {[lsearch -exact $pushservers $server] == -1} {
      if {[catch {rawrequest $server "status"} result]} {
        dict set statusdicts $server [createunknowndata]
        error $result
      }
      dict set statusdicts $server $result
    } elseif {![dict exists $statusdicts $server]} {
      dict set statusdicts $server [createunknowndata]
    }
    set status [getstatus $server]
    if {![string equal $status "ok"]} {
      error "$server server status is \"$status\"."
    }
  }

  proc pushstatus {server statusdict} {
    variable statusdicts
    dict set statusdicts $server $statusdict
  }
  
  proc createunknowndata {} {
    return [dict create \
      status          "unknown" \
      statustimestamp [utcclock::combinedformat now] \
      pid             "unknown" \
      starttimestamp  "unknown" \
    ]
  }

  ########################################################################

  proc getstatus {server} {
    variable pushservers
    set status [dict get [getstatusdict $server] "status"]
    if {![string equal $status "ok"]} {
      return $status
    } elseif {[lsearch -exact $pushservers $server] == -1} {
      return $status
    } else {
      set statusdict [getstatusdict $server]
      set timestamp [dict get $statusdict "timestamp"]
      set datalifeseconds [dict get $statusdict "datalifeseconds"]
      if {[utcclock::diff "now" $timestamp] <= $datalifeseconds} {
        return $status
      } else {
        return "stale"
      }
    }
  }

  proc getstatustimestamp {server} {
    return [dict get [getstatusdict $server] "statustimestamp"]
  }

  proc getstarttimestamp {server} {
    return [dict get [getstatusdict $server] "starttimestamp"]
  }

  proc getpid {server} {
    return [dict get [getstatusdict $server] "pid"]
  }
  
  proc getdata {server key} {
    set status [getstatus $server]
    if {![string equal $status "ok"]} {
      error "status is \"$status\"."
    }
    if {![dict exists [getstatusdict $server] $key]} {
      error "invalid key \"$key\"."
    }
    return [dict get [getstatusdict $server] $key]
  }
  
  ########################################################################

  proc request {server command} {
    set response [rawrequest $server $command]
    if {![string equal $command "status"] && ![string equal $response ""]} {
      log::warning "received unexpected response from $server server: \"$response\"."
    }
    return $response
  }
  
  ########################################################################

  proc checkactivity {server expectedactivity} {
    while {[catch {update $server}] || ![string equal "ok" [getstatus $server]]} {
      coroutine::yield
    }
    set activity [getdata $server "activity"]
    if {![string equal $activity $expectedactivity]} {
      error "$server activity is \"$activity\" rather than \"$expectedactivity\"."
    }
  }
  
  proc waitcheck {server waitedactivity} {
    update $server
    set activity [getdata $server "activity"]
    if {[string equal $activity "error"]} {
      error "$server activity is \"error\"."
    }
    if {[string equal $waitedactivity ""]} {
      set waitedactivity [getdata $server "requestedactivity"]
    }
    return [string equal $activity $waitedactivity]
  }
  
  proc wait {server {pollinterval 100}} {
    set first true
    while {![waitcheck $server ""]} {
      if {$first} {
        log::info "waiting for $server."
        set first false
      }
      coroutine::after $pollinterval
    }
  }
  
  proc waituntil {server waitedactivity {pollinterval 100}} {
    set first true
    while {![waitcheck $server $waitedactivity]} {
      if {$first} {
        log::info "waiting for $server."
        set first false
      }
      coroutine::after $pollinterval
    }
  }
  
  proc waituntilnot {server waitedactivity {pollinterval 100}} {
    set first true
    while {[waitcheck $server $waitedactivity]} {
      if {$first} {
        log::info "waiting for $server."
        set first false
      }
      coroutine::after $pollinterval
    }
  }
  
  proc waituntilstartedcheck {server} {
    if {[catch {update $server}]} {
      return true
    }
    set activity [getdata $server "activity"]
    if {[string equal $activity "starting"]} {
      return true
    } else {
      return false
    }
  }
  
  proc waituntilstarted {server {pollinterval 100}} {
    set first true
    while {[waituntilstartedcheck $server]} {
      if {$first} {
        log::info "waiting until $server is started."
        set first false
      }
      coroutine::after $pollinterval
    }
  }
  
  proc resetifnecessary {server {force false}} {
    update $server
    if {$force || [string equal [getdata $server "activity"] "error"]} {
      log::info "resetting $server."
      request $server "reset"
      wait $server
    }
  }

}
