########################################################################

# This file is part of the UNAM telescope control system.

# $Id: mount.tcl 3594 2020-06-10 14:55:51Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

namespace eval "mount" {

  variable svnid {$Id}
  
  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" mount::initializeactivitycommand 1200000
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "opening" "idle" mount::openactivitycommand 1200000
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] mount::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] mount::resetactivitycommand
  }

  proc reboot {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "rebooting" [server::getstoppedactivity] mount::rebootactivitycommand
  }

  proc preparetomove {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtomove" "preparedtomove" mount::preparetomoveactivitycommand
  }

  proc move {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "moving" "idle" mount::moveactivitycommand
  }

  proc park {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "parking cancelled because $message"
    }
    server::newactivitycommand "parking" "idle" mount::parkactivitycommand
  }

  proc unpark {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "unparking cancelled because $message"
    }
    server::newactivitycommand "unparking" "idle" mount::unparkactivitycommand
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtotrack" "preparedtotrack" mount::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "moving" "tracking" mount::trackactivitycommand
  }

  proc offset {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "offsetting" "tracking" mount::offsetactivitycommand
  }

  proc guide {alphaoffset deltaoffset} {
    server::checkstatus
    server::checkactivity "tracking"
    set alphaoffset [astrometry::parseangle $alphaoffset dms]
    set deltaoffset [astrometry::parseangle $deltaoffset dms]
    log::debug [format "offsetting %s E and %s N to correct guiding." [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset]]
    offsetcommand push $alphaoffset $deltaoffset
    return
    
    set totaloffset [expr {sqrt($alphaoffset * $alphaoffset + $deltaoffset * $deltaoffset)}]
    variable allowedguideoffset
    if {$totaloffset > $allowedguideoffset} {
      log::warning "requested guide offset is too large."
      return
    } else {
      offsetcommand push $alphaoffset $deltaoffset
    }
    return
  }
  
  proc correct {truemountalpha truemountdelta equinox} {
    server::checkstatus
    server::checkactivity "tracking"
    set truemountalpha [astrometry::parsealpha $truemountalpha]
    set truemountdelta [astrometry::parsedelta $truemountdelta]
    set start [utcclock::seconds]
    log::info "correcting at [astrometry::formatalpha $truemountalpha] [astrometry::formatdelta $truemountdelta] $equinox"
    if {[string equal $equinox "observed"]} {
      set truemountobservedalpha $truemountalpha
      set truemountobserveddelta $truemountdelta
    } else {
      set truemountobservedalpha [astrometry::observedalpha $truemountalpha $truemountdelta $equinox]
      set truemountobserveddelta [astrometry::observeddelta $truemountalpha $truemountdelta $equinox]    
    }
    set requestedobservedalpha [server::getdata "requestedobservedalpha"]
    set requestedobserveddelta [server::getdata "requestedobserveddelta"]
    set mountalphaerror [server::getdata "mountalphaerror"]
    set mountdeltaerror [server::getdata "mountdeltaerror"]
    set dalpha [astrometry::foldradsymmetric [expr {$requestedobservedalpha - $truemountobservedalpha + $mountalphaerror}]]
    set ddelta [astrometry::foldradsymmetric [expr {$requestedobserveddelta - $truemountobserveddelta + $mountdeltaerror}]]
    set alphaoffset [expr {$dalpha * cos($truemountobserveddelta)}]
    set deltaoffset $ddelta
    log::info [format "correction is %s E and %s N." [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset]]
    server::setdata "lastcorrectiontimestamp" [utcclock::format]
    server::setdata "lastcorrectiondalpha"    $dalpha
    server::setdata "lastcorrectionddelta"    $ddelta
    set dha [expr {-($dalpha)}]
    updatepointingmodel $dha $ddelta [server::getdata "mountrotation"]
    log::info [format "finished correcting after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc fakecontrollererror {} {
    variable fakecontrollererror
    set fakecontrollererror true
  }

  ######################################################################

  proc start {} {
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" mount::startactivitycommand
  }

}
