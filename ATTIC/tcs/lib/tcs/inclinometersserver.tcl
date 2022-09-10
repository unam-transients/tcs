########################################################################

# This file is part of the UNAM telescope control system.

# $Id: inclinometersserver.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "server"
package require "inclinometers"

package provide "inclinometersserver" 0.0

namespace eval "inclinometersserver" {

  variable svnid {$Id}

  proc slavereset {} {
    inclinometers::reset
  }
  
  proc slavesuspend {} {
    inclinometers::suspend
  }
  
  proc slaveresume {} {
    inclinometers::resume
  }

  proc configureslave {slave} {
    interp alias $slave reset    {} inclinometersserver::slavereset
    interp alias $slave suspend  {} inclinometersserver::slavesuspend
    interp alias $slave resume   {} inclinometersserver::slaveresume
  }

  proc start {} {
    inclinometers::start
    server::listen inclinometers inclinometersserver::configureslave
  }

}
