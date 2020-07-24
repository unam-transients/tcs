////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: fitssoftgain.c 3562 2020-05-22 20:04:34Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2012, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

static int status = 0;
static fitsfile *inputfptr = NULL;
static fitsfile *outputfptr = NULL;

void
check_status(void)
{
  if (status != 0) {
    fprintf(stderr, "fitssoftgain: fatal error:\n");
    fits_report_error(stderr, status);
    if (inputfptr != NULL)
      fits_close_file(inputfptr, &status);
    if (outputfptr != NULL)
      fits_delete_file(outputfptr, &status);
    exit(1);
  }
}

int
main(int argc, char *argv[])
{
  if (argc != 4) {
    fprintf(stderr, "usage: fitssoftgain input gain output.\n");
    exit(1);
  }

  const char *inputfile = argv[1];
  unsigned int softgain = atoi(argv[2]);
  const char *outputfile = argv[3];

  // Open the input file.
  fits_open_file(&inputfptr, inputfile, READONLY, &status);
  check_status();
  
  // Check the input file does not already have a SOFTGAIN card.
  char card[81];
  fits_read_card(inputfptr, "SOFTGAIN", card, &status);
  if (status == 0) {
    fprintf(stderr, "error: \"%s\" has already been processed by fitssoftgain.\n", inputfile);
    exit(1);  
  }
  status = 0;
  
  // Determine the size of the input image.
  int rank;
  fits_get_img_dim(inputfptr, &rank,  &status);
  long dimension[2];
  fits_get_img_size(inputfptr, sizeof(dimension) / sizeof(*dimension), dimension, &status);
  long nx = dimension[0];
  long ny = dimension[1];
  
  // Create the output file.
  fits_create_file(&outputfptr, outputfile, &status);
  fits_create_img(outputfptr, 16, rank, dimension, &status);
  check_status();
  
  // Copy the header from the input file to the output file, update the DATE card, and add a SOFTGAIN card.
  int nrecord;
  int nmorerecord;
  fits_get_hdrspace(inputfptr, &nrecord, &nmorerecord, &status);
  for (int i = 1; i <= nrecord; ++i) {
    char record[81];
    fits_read_record(inputfptr, i, record, &status);
    check_status();
    record[80] = 0;
    if (strncmp(record, "SIMPLE  ", 8) != 0 &&
        strncmp(record, "BITPIX  ", 8) != 0 &&
        strncmp(record, "NAXIS", 5) != 0) {
      fits_write_record(outputfptr, record, &status);
    }
    check_status();
  }
  fits_write_date(outputfptr, &status);
  check_status();
  fits_write_key(outputfptr, TUINT, "SOFTGAIN", &softgain, "", &status);
  check_status();
  
  // Allocate memory for the pixels.
  double *z = malloc(nx * ny * sizeof(*z));
  if (z == NULL) {
    fprintf(stderr, "error: unable to allocate memory for pixel data.\n");
    exit(1);  
  }
  
  // Read the pixels from the input file.
  fits_read_pix(inputfptr, TDOUBLE, (long []) {1, 1}, nx * ny, NULL, z, NULL, &status);
  check_status();

  // Divide the pixels by the software gain.
  for (long i = 0; i < nx * ny; ++i)
    z[i] /= softgain;
    
  // Clip to [-32k,+32k]
  for (long i = 0; i < nx * ny; ++i)
    if (z[i] > 0x7fffL)
      z[i] = 0x7fffL;
  for (long i = 0; i < nx * ny; ++i)
    if (z[i] < -0x8000L)
      z[i] = -0x8000L;


  // Write the pixels to the output file.    
  fits_write_pix(outputfptr, TDOUBLE, (long []) {1, 1}, nx * ny, z, &status);
  check_status();

  // Close the input and output files.
  fits_close_file(inputfptr, &status);
  fits_close_file(outputfptr, &status);
  check_status();
 
  return 0;
}

////////////////////////////////////////////////////////////////////////////////
