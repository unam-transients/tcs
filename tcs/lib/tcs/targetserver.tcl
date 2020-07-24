########################################################################

# This file is part of the UNAM telescope control system.

# $Id: targetserver.tcl 3600 2020-06-11 00:18:39Z Alan $

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

package require "target"
package require "server"

package provide "targetserver" 0.0

namespace eval "targetserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    target::initialize
    return
  }

  proc slavestop {} {
    target::stop
    return
  }

  proc slavereset {} {
    target::reset
    return
  }

  proc slavemove {ha delta} {
    target::move $ha $delta
    return
  }

  proc slavetrack {alpha delta equinox {alphaoffset 0} {deltaoffset 0} {epoch "now"} {alpharate 0} {deltarate 0} {aperture "default"}} {
    if {[string equal $epoch "now"]} {
      set epoch [utcclock::combinedformat]
    }
    target::track $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $aperture
    return
  }

  proc slaveoffset {alphaoffset deltaoffset {aperture "default"}} {
    target::offset $alphaoffset $deltaoffset $aperture
    return
  }

  proc configureslave {slave} {
    interp alias $slave initialize      {} targetserver::slaveinitialize
    interp alias $slave stop            {} targetserver::slavestop
    interp alias $slave reset           {} targetserver::slavereset
    interp alias $slave move            {} targetserver::slavemove
    interp alias $slave track           {} targetserver::slavetrack
    interp alias $slave offset          {} targetserver::slaveoffset
  }

  ######################################################################

  proc start {} {
    target::start
    server::listen target targetserver::configureslave
  }

  ######################################################################

}
