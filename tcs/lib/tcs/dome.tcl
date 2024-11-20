########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2019, 2021, 2024 Alan M. Watson <alan@astro.unam.mx>
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

namespace eval "dome" {

  variable openazimuth          [astrometry::formatazimuth [config::getvalue "dome" "openazimuth"     ]]
  variable closeazimuth         [astrometry::formatazimuth [config::getvalue "dome" "closeazimuth"    ]]
  variable parkazimuth          [astrometry::formatazimuth [config::getvalue "dome" "parkazimuth"     ]]
  
  variable moveazimuthtolerance     [astrometry::parseazimuth [config::getvalue "dome" "moveazimuthtolerance"    ]]
  variable trackingazimuthtolerance [astrometry::parseazimuth [config::getvalue "dome" "trackingazimuthtolerance"]]
  variable settlingseconds          3

  variable daytimetesting       [config::getvalue "telescope" "daytimetesting"]

  ########################################################################

  proc getazimuth {} {
    return [server::getdata "azimuth"]
  }

  proc getazimutherror {} {
    return [server::getdata "azimutherror"]
  }

  proc getshutters {} {
    return [server::getdata "shutters"]
  }

  proc gettargetazimuth {} {
    while {[catch {client::update "target"}]} {
      log::warning "unable to determine the target position."
      coroutine::yield
    }
    set observedazimuth [client::getdata "target" "observedazimuth"]
    return $observedazimuth
  }
  
  proc getanticipateddomeazimuth {} {
    while {[catch {client::update "target"}]} {
      log::warning "unable to determine the target position."
      coroutine::yield
    }
    set observedazimuth     [client::getdata "target" "observedazimuth"]
    set observedazimuthrate [client::getdata "target" "observedazimuthrate"]
    variable trackingazimuthtolerance
    log::info [format "target observed azimuth is %s." [astrometry::formatazimuth $observedazimuth]]   
    if {[string equal $observedazimuthrate ""]} {
      set anticipateddomeazimuth $observedazimuth
    } else {
      log::info [format "target observed azimuth rate %+5fd/s." [astrometry::radtodeg $observedazimuthrate]]
      if {$observedazimuthrate > 0} {
        set anticipateddomeazimuth [astrometry::foldradpositive [expr {$observedazimuth + $trackingazimuthtolerance}]]
      } else {
        set anticipateddomeazimuth [astrometry::foldradpositive [expr {$observedazimuth - $trackingazimuthtolerance}]]
      }
    }
    log::info [format "anticipated dome azimuth is %s." [astrometry::formatazimuth $anticipateddomeazimuth]]   
    return $anticipateddomeazimuth
  }
  
  ########################################################################
  
  proc waitwhilesettling {} {
    variable settlingseconds
    set start [utcclock::seconds]
    while {[utcclock::diff now $start] < $settlingseconds} {
      coroutine::yield
    }
  }
  
  proc waitwhilemoving {} {
    log::info "waiting while moving."
    variable moveazimuthtolerance
    variable settlingseconds
    while {[string equal [getazimutherror] ""]} {
      coroutine::yield
    }
    while {abs([getazimutherror]) > $moveazimuthtolerance} {
      coroutine::yield
    }   
    waitwhilesettling
    log::info "finished waiting while moving."
    if {![string equal [getazimutherror] ""]} {
      if {abs([getazimutherror]) > $moveazimuthtolerance} {
        log::warning [format "azimuth error is %+.2fd after moving." [astrometry::radtodeg [getazimutherror]]]
      }
    }

  }
  
  proc waitwhileopening {} {
    log::info "waiting while opening."
    while {![string equal [getshutters] "open"]} {
      coroutine::yield
    }
    waitwhilesettling   
    log::info "finished waiting while opening."
  }

  proc waitwhileclosing {} {
    log::info "waiting while closing."
    while {![string equal [getshutters] "closed"]} {
      coroutine::yield
    }
    waitwhilesettling   
    log::info "finished waiting while closing."
  }

  ########################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    initializehardware     
    log::info "closing."
    variable closeazimuth
    movehardware [astrometry::parseazimuth $closeazimuth]    
    waitwhilemoving
    closehardware
    waitwhileclosing
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    variable openazimuth
    movehardware [astrometry::parseazimuth $openazimuth]    
    waitwhilemoving
    openhardware
    waitwhileopening
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    variable closeazimuth
    movehardware [astrometry::parseazimuth $closeazimuth]    
    waitwhilemoving
    closehardware
    waitwhileclosing
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::info "emergency closing."
    emergencyclosehardware
    waitwhileclosing
    set end [utcclock::seconds]
    log::info [format "finished emergency closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
    server::setdata requestedazimuth ""
  }
  
  proc moveactivitycommand {azimuth} {
    set start [utcclock::seconds]
    log::info "moving."
    movehardware $azimuth
    waitwhilemoving
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    variable parkazimuth
    log::info "parking."
    movehardware $parkazimuth
    waitwhilemoving
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    server::setdata "requestedazimuth" ""
    server::setdata "requestedshutters" ""
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
    server::setdata "requestedazimuth" ""
  } 

  proc trackactivitycommand {} {
    variable trackingazimuthtolerance
    set first true
    while {true} {
      if {[catch {client::checkactivity "target" "tracking"} message]} {
        log::warning "tracking cancelled because $message"
        return
      }
      set targetazimuth [gettargetazimuth]
      set azimuth       [getazimuth]
      if {abs($targetazimuth - $azimuth) > $trackingazimuthtolerance} {
        set anticipateddomeazimuth [getanticipateddomeazimuth]
        log::info [format "moving dome to azimuth %s." [astrometry::formatazimuth $anticipateddomeazimuth]]   
        movehardware $anticipateddomeazimuth
        waitwhilemoving
      }
      if {$first} {
        set first false
        server::setactivity "tracking"
        server::clearactivitytimeout
      }
      coroutine::yield
    }
  }

  ########################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkhardwarefor "initialize"
    server::newactivitycommand "initializing" "idle" \
      dome::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkhardwarefor "stop"
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "dome::stopactivitycommand [server::getactivity]"
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkhardwarefor "reset"
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "dome::stopactivitycommand [server::getactivity]"
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "open"
    variable daytimetesting
    if {$daytimetesting} {
      server::newactivitycommand "closing" "idle" \
        dome::closeactivitycommand

    } else {
      server::newactivitycommand "opening" "idle" \
        dome::openactivitycommand
    }
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "close"
    server::newactivitycommand "closing" "idle" \
      dome::closeactivitycommand
  }
  
  proc emergencyclose {} {
    server::newactivitycommand "closing" [server::getstoppedactivity] \
      dome::emergencycloseactivitycommand
  }
  
  proc preparetomove {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "preparetomove"
    server::newactivitycommand "preparingtomove" "preparedtomove" \
      dome::preparetomoveactivitycommand
  }

  proc move {azimuth} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "move"
    if {[string equal $azimuth "open"]} {
      variable openazimuth
      set azimuth $openazimuth
    } elseif {[string equal $azimuth "close"]} {
      variable closeazimuth
      set azimuth $closeazimuth
    } elseif {[string equal $azimuth "park"]} {
      variable parkazimuth
      set azimuth $parkazimuth
    } elseif {[string equal $azimuth "target"]} {
      set azimuth [getanticipateddomeazimuth]
    }
    if {[catch {
      astrometry::parseazimuth $azimuth
    }]} {
      error "invalid azimuth \"$azimuth\"."
    }
    set azimuth [astrometry::parseazimuth $azimuth]    
    server::newactivitycommand "moving" "idle" \
      "dome::moveactivitycommand $azimuth"
  }
  
  proc park {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "park"
    server::newactivitycommand "parking" "idle" \
      dome::parkactivitycommand
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "preparetotrack"
    server::newactivitycommand "preparingtotrack" "preparedtotrack" \
      dome::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivityformove
    checkhardwarefor "track"
    server::newactivitycommand "moving" "tracking" \
      dome::trackactivitycommand
  }
  
  ########################################################################

}
