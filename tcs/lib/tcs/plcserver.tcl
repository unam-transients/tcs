########################################################################

# This file is part of the UNAM telescope control system.

# $Id: plcserver.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "plc[config::getvalue "plc" "type"]"
package require "log"
package require "server"

package provide "plcserver" 0.0

namespace eval "plcserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    plc::initialize
  }

  proc slavestop {} {
    plc::stop
  }

  proc slavereset {} {
    plc::reset
  }

  proc slaveswitchlightson {} {
    plc::switchlightson
  }

  proc slaveswitchlightsoff {} {
    plc::switchlightsoff
  }
  
  proc slaveopen {} {
    plc::open
  }

  proc slaveclose {} {
    plc::close
  }
  
  proc configureslave {slave} {
    interp alias $slave initialize      {} plcserver::slaveinitialize
    interp alias $slave stop            {} plcserver::slavestop
    interp alias $slave reset           {} plcserver::slavereset
    interp alias $slave switchlightson  {} plcserver::slaveswitchlightson
    interp alias $slave switchlightsoff {} plcserver::slaveswitchlightsoff
    interp alias $slave open            {} plcserver::slaveopen
    interp alias $slave close           {} plcserver::slaveclose
  }

  ######################################################################

  proc start {} {
    plc::start
    server::listen plc plcserver::configureslave
  }

  ######################################################################

}
