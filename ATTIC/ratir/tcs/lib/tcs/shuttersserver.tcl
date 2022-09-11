########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "shutters"
package require "log"
package require "server"

package provide "shuttersserver" 0.0

namespace eval "shuttersserver" {

  ######################################################################

  proc slaveinitialize {} {
    shutters::initialize
  }

  proc slavestop {} {
    shutters::stop
  }

  proc slavereset {} {
    shutters::reset
  }

  proc slaveopen {} {
    shutters::open
  }

  proc slaveclose {} {
    shutters::close
  }

  proc slaveemergencyclose {} {
    shutters::emergencyclose
  }

  proc configureslave {slave} {
    interp alias $slave initialize     {} shuttersserver::slaveinitialize
    interp alias $slave stop           {} shuttersserver::slavestop
    interp alias $slave reset          {} shuttersserver::slavereset
    interp alias $slave open           {} shuttersserver::slaveopen
    interp alias $slave close          {} shuttersserver::slaveclose
    interp alias $slave emergencyclose {} shuttersserver::slaveemergencyclose
  }

  ######################################################################

  proc start {} {
    shutters::start
    server::listen shutters shuttersserver::configureslave
  }

  ######################################################################

}
