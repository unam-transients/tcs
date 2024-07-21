########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "server"

package require "dome[config::getvalue "dome" "type"]"

package provide "domeserver" 0.0

namespace eval "domeserver" {

  ######################################################################

  proc slaveinitialize {} {
    dome::initialize
    return
  }

  proc slavestop {} {
    dome::stop
    return
  }

  proc slavereset {} {
    dome::reset
    return
  }

  proc slaveopen {} {
    dome::open
  }

  proc slaveclose {} {
    dome::close
  }

  proc slaveemergencyclose {} {
    dome::emergencyclose
  }

  proc slavepreparetomove {} {
    dome::preparetomove
    return
  }

  proc slavemove {{azimuth "target"}} {
    dome::move $azimuth
    return
  }

  proc slavepark {} {
    dome::park
    return
  }

  proc slavepreparetotrack {} {
    dome::preparetotrack
    return
  }

  proc slavetrack {} {
    dome::track
    return
  }

  proc configureslave {slave} {
    interp alias $slave initialize     {} domeserver::slaveinitialize
    interp alias $slave stop           {} domeserver::slavestop
    interp alias $slave reset          {} domeserver::slavereset
    interp alias $slave open           {} domeserver::slaveopen
    interp alias $slave close          {} domeserver::slaveclose
    interp alias $slave emergencyclose {} domeserver::slaveemergencyclose
    interp alias $slave preparetomove  {} domeserver::slavepreparetomove
    interp alias $slave move           {} domeserver::slavemove
    interp alias $slave park           {} domeserver::slavepark
    interp alias $slave preparetotrack {} domeserver::slavepreparetotrack
    interp alias $slave track          {} domeserver::slavetrack

  }

  ######################################################################

  proc start {} {
    dome::start
    server::listen dome domeserver::configureslave
  }

  ######################################################################

}
