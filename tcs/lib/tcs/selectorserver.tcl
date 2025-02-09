########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "selector"
package require "log"
package require "server"

package provide "selectorserver" 0.0

namespace eval "selectorserver" {

  ######################################################################

  proc slavestop {} {
    selector::stop
    return
  }

  proc slavereset {} {
    selector::reset
    return
  }

  proc slaveenable {} {
    selector::enable
    return
  }

  proc slavedisable {} {
    selector::disable
    return
  }
  
  proc slaverespondtoalert {blockidentifier name origin identifier type alerttimestamp eventtimestamp enabled alpha delta equinox uncertainty class messenger} {
    selector::respondtoalert $blockidentifier $name $origin $identifier $type $alerttimestamp $eventtimestamp $enabled $alpha $delta $equinox $uncertainty $class $messenger
  }

  proc slaverespondtolvcalert {blockidentifier name origin identifier type alerttimestamp eventtimestamp enabled skymapurl class} {
    selector::respondtolvcalert $blockidentifier $name $origin $identifier $type $alerttimestamp $eventtimestamp $enabled $skymapurl $class
  }

  proc slavesetfocused {} {
    selector::setfocused
  }

  proc slavesetunfocused {} {
    selector::setunfocused
  }
  
  proc slaverefocus {} {
    selector::refocus
  }
  
  proc slavemakealertspage {} {
    selector::makealertspage
  }

  proc slaveenablealert {identifier} {
    selector::enablealert $identifier
  }

  proc slavedisablealert {identifier} {
    selector::disablealert $identifier
  }

  proc slavemodifyalert {identifier alpha delta equinox uncertainty maxalertdelay priority} {
    selector::modifyalert $identifier $alpha $delta $equinox $uncertainty $maxalertdelay $priority
  }

  proc slavecreatealert {name eventtimestamp alpha delta equinox uncertainty priority} {
    selector::createalert $name $eventtimestamp $alpha $delta $equinox $uncertainty $priority
  }

  proc configureslave {slave} {
    interp alias $slave stop              {} selectorserver::slavestop
    interp alias $slave reset             {} selectorserver::slavereset
    interp alias $slave enable            {} selectorserver::slaveenable
    interp alias $slave disable           {} selectorserver::slavedisable
    interp alias $slave respondtoalert    {} selectorserver::slaverespondtoalert
    interp alias $slave respondtolvcalert {} selectorserver::slaverespondtolvcalert
    interp alias $slave setfocused        {} selectorserver::slavesetfocused
    interp alias $slave setunfocused      {} selectorserver::slavesetunfocused
    interp alias $slave refocus           {} selectorserver::slaverefocus
    interp alias $slave makealertspage       {} selectorserver::slavemakealertspage
    interp alias $slave enablealert       {} selectorserver::slaveenablealert
    interp alias $slave disablealert      {} selectorserver::slavedisablealert
    interp alias $slave modifyalert       {} selectorserver::slavemodifyalert
    interp alias $slave createalert       {} selectorserver::slavecreatealert
  }

  ######################################################################

  proc start {} {
    selector::start
    server::listen selector selectorserver::configureslave
  }

  ######################################################################

}
