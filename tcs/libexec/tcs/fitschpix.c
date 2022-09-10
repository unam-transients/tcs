////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2012, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
//
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the
// above copyright notice and this permission notice appear in all
// copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
// DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
// PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
// TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

////////////////////////////////////////////////////////////////////////

// The OAN controllers typically use 16-bit little-endian unsigned
// integers for pixel data. FITS needs 16-bit big-endian signed integers
// with appropriate values of BZERO and BSCALE. This program reads at
// most n bytes, converts unsigned integers to signed integers, swaps
// the bytes, and pads with zeros the first multiple of 2880 bytes that
// is at least n.

#include <stdio.h>
#include <stdlib.h>

int
main(int argc, char **argv)
{
  long n = atol(argv[1]);
  long i = 0;
  long j = 0;

  for (;;) {
    
    if (i == n)
      break;
    int b0 = getchar();
    ++i;
    if (b0 == EOF)
      break;
      
    if (i == n)
      break;
    int b1 = getchar();
    ++i;
    if (b1 == EOF)
      break;

    // Convert to original value.
    long u = b0 + 256 * b1;
    
    // Convert to scaled signed value.
    long s = u - 32768;

    // Convert to bytes, assuming the internal representation is two's complement.
    b0 = (unsigned long) s & 0xFF;
    b1 = ((unsigned long) s >> 8) & 0xFF;

    // Swap bytes.
    putchar(b1);
    putchar(b0);
    
    j += 2;
  }
  
  // Replace missing data with 0 bytes and pad to FITS record boundary.
  while (j < n || j % 2880 != 0) {
    putchar(0);
    ++j;
  }
  
  return 0;
}
