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
  
  variable trackingtolerance    [astrometry::parseazimuth [config::getvalue "dome" "trackingtolerance"   ]]

  variable daytimetesting       [config::getvalue "telescope" "daytimetesting"]

  ########################################################################

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
    variable trackingtolerance
    log::info [format "target observed azimuth is %s." [astrometry::formatazimuth $observedazimuth]]   
    log::info [format "target observed azimuth rate %s." $observedazimuthrate]   
    if {[string equal $observedazimuthrate ""] || $observedazimuthrate > 0} {
      set anticipateddomeazimuth $observedazimuth
    } elseif {$observedazimuthrate > 0} {
      set anticipateddomeazimuth [astrometry::foldradpositive [expr {$observedazimuth + $trackingtolerance}]]
    } else {
      set anticipateddomeazimuth [astrometry::foldradpositive [expr {$observedazimuth - $trackingtolerance}]]
    }
    log::info [format "anticipated dome azimuth is %s." [astrometry::formatazimuth $anticipateddomeazimuth]]   
    return $anticipateddomeazimuth
  }
  
  ######################################################################
  
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
    variable openazimuth
    movehardware [astrometry::parseazimuth $openazimuth]    
    log::info "closing."
    closehardware
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    openhardware
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    closehardware
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::warning "emergency closing."
    emergencyclosehardware
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
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    variable parkazimuth
    log::info "parking."
    movehardware $parkazimuth
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    server::setdata "requestedshutters" ""
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
    server::setdata requestedazimuth ""
    #stopmeasuringmaxabsazimutherror
  } 

  proc trackactivitycommand {} {
    #stopmeasuringmaxabsazimutherror

    variable trackingtolerance

    # Move to the target azimuth.
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      log::warning "tracking cancelled because $message"
      return
    }
    set azimuth [getanticipateddomeazimuth]
    log::info [format "moving dome to azimuth %s." [astrometry::formatazimuth $azimuth]]   
    server::setdata requestedazimuth $azimuth
    movehardware $azimuth
    set lastazimuth $azimuth
    
    server::setactivity "tracking"
    server::clearactivitytimeout

    while {true} {
      if {[catch {client::checkactivity "target" "tracking"} message]} {
        log::warning "tracking cancelled because $message"
        return
      }
      set azimuth [gettargetazimuth]
      set dazimuth [astrometry::foldradsymmetric [expr {$azimuth - $lastazimuth}]]
      if {abs($dazimuth) > $trackingtolerance} {
        set azimuth [getanticipateddomeazimuth]
        log::info [format "moving dome to azimuth %s." [astrometry::formatazimuth $azimuth]]   
        server::setdata requestedazimuth $azimuth
        movehardware $azimuth
        set lastazimuth $azimuth
      }
      coroutine::yield
    }
  }

  ########################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" \
      dome::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "dome::stopactivitycommand [server::getactivity]"
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "dome::stopactivitycommand [server::getactivity]"
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
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
    server::newactivitycommand "preparingtomove" "preparedtomove" \
      dome::preparetomoveactivitycommand
  }

  proc move {azimuth} {
    server::checkstatus
    server::checkactivity "preparedtomove"
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
    set azimuth [astrometry::parseazimuth $azimuth]    
    server::newactivitycommand "moving" "idle" \
      "dome::moveactivitycommand $azimuth"
  }
  
  proc park {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    server::newactivitycommand "parking" "idle" \
      dome::parkactivitycommand
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtotrack" "preparedtotrack" \
      dome::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    server::newactivitycommand "moving" "tracking" \
      dome::trackactivitycommand
  }
  
}
