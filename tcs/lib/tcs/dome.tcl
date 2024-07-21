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

  variable openazimuth      [astrometry::formatazimuth [config::getvalue "dome" "openazimuth"     ]]
  variable closeazimuth     [astrometry::formatazimuth [config::getvalue "dome" "closeazimuth"    ]]
  variable parkazimuth      [astrometry::formatazimuth [config::getvalue "dome" "parkazimuth"     ]]

  ########################################################################

  proc gettargetdomeazimuth {} {
    while {[catch {client::update "target"}]} {
      log::warning "unable to determine the target position."
      coroutine::yield
    }
    set targetobservedazimuth [client::getdata "target" "observedazimuth"]
    return $targetobservedazimuth
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
    server::newactivitycommand "opening" "idle" \
      dome::openactivitycommand
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "closing" "idle" \
      dome::closeactivitycommand
  }
  
  proc preparetomove {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtomove" "preparedtomove" dome::preparetomoveactivitycommand
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
      set azimuth [gettargetdomeazimuth]
    }
    set azimuth [astrometry::parseazimuth $azimuth]    
    server::newactivitycommand "moving" "idle" "dome::moveactivitycommand $azimuth"
  }
  
  proc park {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    server::newactivitycommand "parking" "idle" "dome::parkactivitycommand"
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtotrack" "preparedtotrack" dome::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    server::newactivitycommand "moving" "tracking" "dome::trackactivitycommand"
  }
  
}
