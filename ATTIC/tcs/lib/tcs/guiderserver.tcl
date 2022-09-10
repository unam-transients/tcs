########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2011, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "guider"
package require "log"
package require "server"

package provide "guiderserver" 0.0

namespace eval "guiderserver" {

  ######################################################################

  proc slaveinitialize {} {
    guider::initialize
  }
  
  proc slavestop {} {
    guider::stop
  }
  
  proc slavereset {} {
    guider::reset
  }

  proc slaveguide {{errorsource "finder"}} {
    guider::guide $errorsource
  }

  proc configureslave {slave} {
    interp alias $slave initialize         {} guiderserver::slaveinitialize
    interp alias $slave stop               {} guiderserver::slavestop
    interp alias $slave reset              {} guiderserver::slavereset
    interp alias $slave guide              {} guiderserver::slaveguide
  }

  ######################################################################

  proc start {} {
    guider::start
    server::listen guider guiderserver::configureslave
  }

  ######################################################################

}
