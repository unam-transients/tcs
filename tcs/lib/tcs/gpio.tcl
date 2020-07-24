########################################################################

# This file is part of the UNAM telescope control system.

# $Id: gpio.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "gpio" 0.0

namespace eval "gpio" {

  variable svnid {$Id}

  proc get {path} {
    if {[catch {::set channel [::open $path "r"]} why]} {
      error "gpio::get: unable to open GPIO device \"$path\": $why."
    } elseif {[catch {::set rawvalue [gets $channel]} why]} {
      error "gpio::get: unable to read from GPIO device \"$path\": $why."
      catch {close $channel}
    }
    catch {close $channel}
    if {$rawvalue == 0} {
      ::set value "off"
    } else {
      ::set value "on"
    }
    return $value
  }

  proc set {path value} {
    if {[string equal $value "off"]} {
      ::set rawvalue 0
    } elseif {[string equal $value "on"]} {
      ::set rawvalue 1
    } else {
      error "gpio::set: invalid value \"$value\"."
    }
    if {[catch {::set channel [::open $path "w"]} why]} {
      error "gpio::set: unable to open GPIO device \"$path\": $why."
    } elseif {[catch {puts $channel $rawvalue} why]} {
      error "gpio::set: unable to write to GPIO device \"$path\": $why."
      catch {close $channel}
    }
    catch {close $channel}
    return $value
  }

}
