########################################################################
# This file is part of the UNAM telescope control system.
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
  proc get {gpio} {
    if {[catch {::set rawvalue [exec gpioget gpiochip0 $gpio]} why]} {
      error "gpio::get: unable to read from GPIO $gpio: $why."
    }
    if {$rawvalue == 0} {
      ::set value "off"
    } else {
      ::set value "on"
    }
    return $value
  }

  proc set {gpio value} {
    if {[string equal $value "off"]} {
      ::set rawvalue 0
    } elseif {[string equal $value "on"]} {
      ::set rawvalue 1
    } else {
      error "gpio::set: invalid value \"$value\"."
    }
    if {[catch {exec gpioset gpiochip0 $gpio=$rawvalue} why]} {
      error "gpio::set: unable to write to GPIO $gpio: $why."
    }
    return $value
  }
}
