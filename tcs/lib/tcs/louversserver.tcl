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

package require "louvers[config::getvalue "louvers" "type"]"
package require "config"
package require "log"
package require "server"

package provide "louversserver" 0.0

namespace eval "louversserver" {

  ######################################################################

  proc slaveinitialize {} {
    louvers::initialize
  }

  proc slaveopen {} {
    louvers::open
  }

  proc slaveclose {} {
    louvers::close
  }

  proc slavecool {} {
    louvers::cool
  }

  proc configureslave {slave} {
    interp alias $slave reset          {} server::handlereset
    interp alias $slave stop           {} server::handlestop
    interp alias $slave initialize     {} louversserver::slaveinitialize
    interp alias $slave open           {} louversserver::slaveopen
    interp alias $slave close          {} louversserver::slaveclose
    interp alias $slave cool           {} louversserver::slavecool
    interp alias $slave emergencyclose {} louversserver::slaveemergencyclose
  }

  ######################################################################

  proc start {} {
    louvers::start
    server::listen louvers louversserver::configureslave
  }

  ######################################################################

}
