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
package require "log"
package require "server"

package require "tertiary[config::getvalue "tertiary" "type"]"

package provide "tertiaryserver" 0.0

namespace eval "tertiaryserver" {

  ######################################################################

  proc slaveinitialize {} {
    tertiary::initialize
  }

  proc slavereset {} {
    tertiary::reset
  }

  proc slavesetport {port} {
    tertiary::setport $port
  }

  proc configureslave {slave} {
    interp alias $slave initialize {} tertiaryserver::slaveinitialize
    interp alias $slave setport    {} tertiaryserver::slavesetport
  }

  ######################################################################

  proc start {} {
    tertiary::start
    server::listen tertiary tertiaryserver::configureslave
  }

  ######################################################################

}
