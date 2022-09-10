########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

source utcclock.tcl

puts [utcclock::getresolution]
puts [utcclock::getprecision]
set seconds [utcclock::seconds]
puts $seconds
puts [utcclock::format $seconds]
puts [utcclock::format $seconds 3]
puts [utcclock::combinedformat $seconds]
puts [utcclock::combinedformat $seconds 3]
puts [utcclock::combinedformat $seconds 0 false]
puts [utcclock::combinedformat $seconds 3 false]
puts [utcclock::scan [utcclock::format $seconds]]
puts [utcclock::scan [utcclock::format $seconds 3]]
puts [utcclock::scan [utcclock::combinedformat $seconds]]
puts [utcclock::scan [utcclock::combinedformat $seconds 3]]
puts [utcclock::scan [utcclock::combinedformat $seconds 0 false]]
puts [utcclock::scan [utcclock::combinedformat $seconds 3 false]]
puts [utcclock::formatdate now]
puts [utcclock::formattime now 3]
puts [utcclock::formatinterval 10]
puts [utcclock::formatinterval 100]
puts [utcclock::formatinterval 1000]
puts [utcclock::formatinterval 10000]

