////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: fitsmean.c 3373 2019-10-30 15:09:02Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2011, 2012, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include <math.h>
#include <string.h>

#include <fitsio.h>

int
main(int argc, char *argv[])
{
  if (argc != 6) {
    fprintf(stderr, "usage: tcs %s fits_name wsx wnx wsy wny.\n", argv[0]);
    exit(1);
  }

  const char *fits_file = argv[1];
  long wsx = atol(argv[2]);
  long wnx = atol(argv[3]);
  long wsy = atol(argv[4]);
  long wny = atol(argv[5]);

  fitsfile *ffp;         
  int status = 0;

  fits_open_file(&ffp, fits_file, READONLY, &status);
      
  int rank;
  fits_get_img_dim(ffp, &rank,  &status);
  long dimension[2];
  fits_get_img_size(ffp, sizeof(dimension) / sizeof(*dimension), dimension, &status);
  long nx = dimension[0];
  long ny = dimension[1];
  double *z = malloc(nx * ny * sizeof(*z));
  if (z == NULL)
    abort();
  fits_read_pix(ffp, TDOUBLE, (long []) {1, 1}, nx * ny, NULL, z, NULL, &status);
  fits_close_file(ffp, &status);
  if (status) {
    fits_report_error(stderr, status);
    exit(1);
  }

#define Z(iy,ix) (z[(iy) * nx + (ix)])   

  double s0 = 0.0;
  double s1 = 0.0;
  double s2 = 0.0;
  for (int iy = wsy; iy < wsy + wny; ++iy) {
    for (int ix = wsx; ix < wsx + wnx; ++ix) {
      s0 += 1.0;
      s1 += Z(iy, ix);
      s2 += Z(iy, ix) + Z(iy, ix);
    }
  }
  double mean = s1 / s0;
  double standarddeviation = sqrt((s2 / s0) - (s1 / s0) * (s1 / s0));
  printf("%.1f %.1f\n", mean, standarddeviation);
  
  return 0;
}

////////////////////////////////////////////////////////////////////////////////
