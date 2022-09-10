########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "mount[config::getvalue "mount" "type"]"
package require "log"
package require "server"

package provide "mountserver" 0.0

namespace eval "mountserver" {

  ######################################################################

  proc slaveinitialize {} {
    mount::initialize
    return
  }

  proc slaveopen {} {
    mount::open
    return
  }

  proc slavestop {} {
    mount::stop
    return
  }

  proc slavereset {} {
    mount::reset
    return
  }

  proc slavereboot {} {
    mount::reboot
    return
  }

  proc slavepreparetomove {} {
    mount::preparetomove
    return
  }

  proc slavemove {} {
    mount::move
    return
  }

  proc slavepark {} {
    mount::park
    return
  }

  proc slaveunpark {} {
    mount::unpark
    return
  }

  proc slavepreparetotrack {} {
    mount::preparetotrack
    return
  }

  proc slavetrack {} {
    mount::track
    return
  }

  proc slaveoffset {} {
    mount::offset
    return
  }

  proc slaveguide {dalpha ddelta} {
    mount::guide $dalpha $ddelta
    return
  }

  proc slavecorrect {truemountalpha truemountdelta equinox} {
    mount::correct $truemountalpha $truemountdelta $equinox
    return
  }

  proc slavesetMAtozero {} {
    mount::setMAtozero
    return
  }

  proc slavesetMEtozero {} {
    mount::setMEtozero
    return
  }

  proc configureslave {slave} {
    interp alias $slave initialize          {} mountserver::slaveinitialize
    interp alias $slave open                {} mountserver::slaveopen
    interp alias $slave stop                {} mountserver::slavestop
    interp alias $slave reset               {} mountserver::slavereset
    interp alias $slave reboot              {} mountserver::slavereboot
    interp alias $slave preparetomove       {} mountserver::slavepreparetomove
    interp alias $slave move                {} mountserver::slavemove
    interp alias $slave park                {} mountserver::slavepark
    interp alias $slave unpark              {} mountserver::slaveunpark
    interp alias $slave preparetotrack      {} mountserver::slavepreparetotrack
    interp alias $slave track               {} mountserver::slavetrack
    interp alias $slave offset              {} mountserver::slaveoffset
    interp alias $slave guide               {} mountserver::slaveguide
    interp alias $slave correct             {} mountserver::slavecorrect
    interp alias $slave setMAtozero         {} mountserver::slavesetMAtozero
    interp alias $slave setMEtozero         {} mountserver::slavesetMEtozero
  }

  ######################################################################

  proc start {} {
    mount::start
    server::listen mount mountserver::configureslave
  }

  ######################################################################

}
