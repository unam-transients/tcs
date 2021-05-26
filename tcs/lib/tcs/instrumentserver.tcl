########################################################################

# This file is part of the RATTEL instrument control system.

# $Id: instrumentserver.tcl 3592 2020-06-10 14:32:51Z Alan $

########################################################################

# Copyright © 2014, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "instrument"
package require "log"
package require "server"

package provide "instrumentserver" 0.0

namespace eval "instrumentserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    instrument::initialize
    return
  }

  proc slaveopen {} {
    instrument::open
    return
  }

  proc slaveopentocool {} {
    instrument::opentocool
    return
  }

  proc slaveclose {} {
    instrument::close
    return
  }

  proc slaveemergencyclose {} {
    instrument::emergencyclose
    return
  }

  proc slavestop {} {
    instrument::stop
    return
  }

  proc slavereset {} {
    instrument::reset
    return
  }
  
  proc slaverecover {} {
    instrument::recover
    return
  }

  proc slaveidle {} {
    instrument::idle
    return
  }
  
  proc slaveexpose {type fitsfiledir args} {
    eval instrument::expose $type $fitsfiledir $args
  }
  
  proc slaveanalyze {args} {
    eval instrument::analyze $args
  }
  
  proc slavesetreadmode {args} {
    eval instrument::setreadmode $args
    return
  }
  
  proc slavesetwindow {args} {
    eval instrument::setwindow $args
    return
  }
  
  proc slavesetbinning {args} {
    eval instrument::setbinning $args
    return
  }
  
  proc slavesetfocuser {args} {
    eval instrument::setfocuser $args
    return
  }
  
  proc slavemovefilterwheel {args} {
    eval instrument::movefilterwheel $args
    return
  }
  
  proc slavefocus {fitsfileprefix range step witness args} {
    eval instrument::focus $fitsfileprefix $range $step $witness $args
    return
  }
  
  proc slavemapfocus {fitsfileprefix range step args} {
    eval instrument::mapfocus $fitsfileprefix $range $step $args
    return
  }
  
  proc configureslave {slave} {
    interp alias $slave initialize           {} instrumentserver::slaveinitialize
    interp alias $slave open                 {} instrumentserver::slaveopen
    interp alias $slave opentocool           {} instrumentserver::slaveopentocool
    interp alias $slave close                {} instrumentserver::slaveclose
    interp alias $slave emergencyclose       {} instrumentserver::slaveemergencyclose
    interp alias $slave stop                 {} instrumentserver::slavestop
    interp alias $slave reset                {} instrumentserver::slavereset
    interp alias $slave recover              {} instrumentserver::slaverecover 
    interp alias $slave idle                 {} instrumentserver::slaveidle
    interp alias $slave movefilterwheel      {} instrumentserver::slavemovefilterwheel
    interp alias $slave expose               {} instrumentserver::slaveexpose
    interp alias $slave analyze              {} instrumentserver::slaveanalyze
    interp alias $slave setreadmode          {} instrumentserver::slavesetreadmode
    interp alias $slave setwindow            {} instrumentserver::slavesetwindow
    interp alias $slave setbinning           {} instrumentserver::slavesetbinning
    interp alias $slave setfocuser           {} instrumentserver::slavesetfocuser
    interp alias $slave movefilterwheel      {} instrumentserver::slavemovefilterwheel
    interp alias $slave focus                {} instrumentserver::slavefocus
    interp alias $slave mapfocus             {} instrumentserver::slavemapfocus
  }

  ######################################################################

  proc start {} {
    instrument::start
    server::listen instrument instrumentserver::configureslave
  }

  ######################################################################

}
