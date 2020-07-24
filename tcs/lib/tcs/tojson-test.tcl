########################################################################

# This file is part of the UNAM telescope control system.

# $Id: astrometry-test.tcl 3335 2019-07-01 18:45:22Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

set prefix [file normalize [file join [file dirname [info script]] ".." ".."]]
source [file join [directories::prefix] "lib" "tcs" "packages.tcl"]

package require "tojson"

puts [tojson::string "abcd\"\\efgh"]
puts [tojson::array [list 0 [tojson::string "1"] [tojson::string "two"] [tojson::string "three"] 4]]
puts [tojson::array [list 0 1 two three 4] string]

puts [tojson::object {one 1 two 2 three 3 four 4}]
puts [tojson::object {one 1 two 2 three 3 four 4} string]
