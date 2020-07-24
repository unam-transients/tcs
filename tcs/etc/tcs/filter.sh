########################################################################

# This file is part of the UNAM telescope control system.

# $Id: filter.sh 3373 2019-10-30 15:09:02Z Alan $

########################################################################

# Copyright © 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

awk '
BEGIN {
  pi = 4.0 * atan2(1.0, 1.0);
  n = 100;
  d = 1.0 / n;
  fwhm = 2;
  sigma = fwhm / (2 * sqrt(2 * log(2)));
  for (iy = -2; iy <= 2; ++iy) {
    for (ix = -2; ix <= 2; ix += 1) {
      z = 0;
      for (fy = -0.5 + 0.5 * d; fy <= 0.5; fy += d) {
        for (fx = -0.5 + 0.5 * d; fx <= 0.5; fx += d) {
          x = ix + fx;
          y = iy + fy;
          r = sqrt(x * x + y * y);
          z += exp(-(r * r) / (2 * sigma * sigma)) / (n * n) / (2 * pi * sigma * sigma);
        }
      }
      printf("%.6f ", z);
      t += z;
    }
    printf("\n");
  }
    printf("%.6f\n", t)
}
' /dev/null
