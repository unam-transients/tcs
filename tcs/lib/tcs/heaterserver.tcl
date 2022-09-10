########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "heater"
package require "log"
package require "server"

package provide "heaterserver" 0.0

namespace eval "heaterserver" {

  ######################################################################

  proc slaveswitchon {} {
    heater::switchon
  }

  proc slaveswitchoff {} {
    heater::switchoff
  }

  proc slaveswitchautomatically {} {
    heater::switchautomatically
  }

  proc configureslave {slave} {
    interp alias $slave reset               {} server::handlereset
    interp alias $slave stop                {} server::handlestop
    interp alias $slave switchon            {} heaterserver::slaveswitchon
    interp alias $slave switchoff           {} heaterserver::slaveswitchoff
    interp alias $slave switchautomatically {} heaterserver::slaveswitchautomatically
  }

  ######################################################################

  proc start {} {
    heater::start
    server::listen heater heaterserver::configureslave
  }

  ######################################################################

}
