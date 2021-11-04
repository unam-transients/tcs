########################################################################

# This file is part of the UNAM telescope control system.

# $Id: secondaryserver.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "secondary[config::getvalue "secondary" "type"]"
package require "log"
package require "server"

package provide "secondaryserver" 0.0

namespace eval "secondaryserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    secondary::initialize
    return
  }

  proc slavestop {} {
    secondary::stop
    return
  }

  proc slavereset {} {
    secondary::reset
    return
  }

  proc slavemovewithoutcheck {z0} {
    secondary::movewithoutcheck $z0
    return
  }

  proc slavemove {z0 {setasinitial false}} {
    secondary::move $z0 $setasinitial
    return
  }

  proc slavemoveforfilter {filter} {
    secondary::moveforfilter $filter
    return
  }

  proc slavesetoffset {dzoffset} {
    secondary::setoffset $dzoffset
    return
  }

  proc configureslave {slave} {
    interp alias $slave initialize       {} secondaryserver::slaveinitialize
    interp alias $slave reset            {} secondaryserver::slavereset
    interp alias $slave stop             {} secondaryserver::slavestop
    interp alias $slave movewithoutcheck {} secondaryserver::slavemovewithoutcheck
    interp alias $slave move             {} secondaryserver::slavemove
    interp alias $slave moveforfilter    {} secondaryserver::slavemoveforfilter
    interp alias $slave setoffset        {} secondaryserver::slavesetoffset
  }

  ######################################################################

  proc start {} {
    secondary::start
    server::listen secondary secondaryserver::configureslave
  }

  ######################################################################

}
