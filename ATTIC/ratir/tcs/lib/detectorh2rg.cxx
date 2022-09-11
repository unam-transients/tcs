////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2013, 2014, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include <float.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fitsio.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

static char description[DETECTOR_STR_BUFFER_SIZE] = "";
static char readmode[DETECTOR_STR_BUFFER_SIZE] = "";
static char identifier[DETECTOR_STR_BUFFER_SIZE] = "";
static char execpath[DETECTOR_STR_BUFFER_SIZE] = "";

static unsigned long fullnx = 0;
static unsigned long fullny = 0;
static unsigned long windowsx = 0;
static unsigned long windowsy = 0;
static unsigned long windownx = 0;
static unsigned long windowny = 0;
static unsigned long binning = 1;

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawopen(char *newidentifier)
{
  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently opened.");

  if (strcmp(newidentifier, "C2") != 0 && strcmp(newidentifier, "C3") != 0)
    return "invalid H2RG identifier.";
  snprintf(identifier, sizeof(identifier), "%s", newidentifier);
  snprintf(description, sizeof(description), "H2RG (%s)", identifier);    
  
  detectorrawsetisopen(true);
  
  fullnx = 2048;
  fullny = 2048;
  
  return detectorrawsetwindow(0, 0, 2048, 2048);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  detectorrawsetisopen(false);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawreset(void)
{
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

static char *rawfitspath;
static char *tcsprefix;

const char *
detectorrawexpose(double exposuretime, const char *shutter)
{
  DETECTOR_CHECK_OPEN();
  rawfitspath = getenv("RAWFITSPATH");
  if (rawfitspath == NULL)
    DETECTOR_ERROR("RAWFITSPATH is not set in the environment.");
  unlink(rawfitspath);
  tcsprefix = getenv("tcsprefix");
  if (tcsprefix == NULL)
    DETECTOR_ERROR("tcsprefix is not set in the environment.");
  snprintf(execpath, sizeof(execpath), "%s/bin/tcs", tcsprefix);
  pid_t childpid = fork();
  if (childpid == 0) {
    char exposuretimearg[DETECTOR_STR_BUFFER_SIZE];
    snprintf(exposuretimearg, sizeof(exposuretimearg), "%.3f", exposuretime);
    execl(execpath, "tcs", "h2rgexpose", identifier, rawfitspath, exposuretimearg, readmode, NULL);
  } else if (childpid < 0) {
    DETECTOR_ERROR("fork() failed.");
  }
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool
detectorrawgetreadytoberead(void)
{
  DETECTOR_CHECK_OPEN();
  struct stat buf;
  return stat(rawfitspath, &buf) == 0;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawread(void)
{
  DETECTOR_CHECK_OPEN();
  if (!detectorrawgetreadytoberead())
    DETECTOR_ERROR("the detector is not ready to be read.");

  unsigned long nx = detectorrawgetpixnx();
  unsigned long ny = detectorrawgetpixny();

  fitsfile *ffp;         
  int status = 0;

  fits_open_file(&ffp, rawfitspath, READONLY, &status);
      
  int rank;
  fits_get_img_dim(ffp, &rank,  &status);
  long dimension[rank];
  fits_get_img_size(ffp, sizeof(dimension) / sizeof(*dimension), dimension, &status);  
  if (rank != 2 || (unsigned long) dimension[0] != nx || (unsigned long) dimension[1] != ny)
    DETECTOR_ERROR("the raw FITS file does not have the expected structure.");
  
  float *fbuf = (float *) malloc(nx * ny * sizeof(*fbuf));
  if (fbuf == NULL)
    DETECTOR_ERROR("malloc() failed.");

  long fpixel[] = {1, 1};
  fits_read_pix(ffp, TFLOAT, fpixel, nx * ny, NULL, fbuf, NULL, &status);
  fits_close_file(ffp, &status);
  if (status)
    DETECTOR_ERROR("unable to read the raw FITS file.");

  long lbuf[nx];
  for (unsigned long iy = 0; iy < ny; ++iy) {
    for (unsigned long ix = 0; ix < nx; ++ix) {
      lbuf[ix] = floor(fbuf[iy * nx + ix]);
    }
    detectorrawpixnext(lbuf, nx);
  }

  free(fbuf);

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPEN();
  char *s;
  long l = strtol(newreadmode, &s, 10);
  if (strcmp(newreadmode, "") == 0 || *s != 0 || l < 1)
    DETECTOR_ERROR("invalid readmode.");
  snprintf(readmode, sizeof(readmode), "%ld", l);
  DETECTOR_OK();
}

const char *
detectorrawgetreadmode(void)
{
  return readmode;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetwindow(unsigned long newsx, unsigned long newsy, unsigned long newnx, unsigned long newny)
{
  DETECTOR_CHECK_OPEN();
  if (newsx == 0 && newnx == 0) {
    newnx = fullnx;
  }
  if (newsy == 0 && newny == 0) {
    newny = fullny;
  }
  if (newsx != 0 && newsy != 0 && newnx != 2048 && newny != 2048)
    DETECTOR_ERROR("unable to set the detector window.");
  windowsx = newsx;
  windowsy = newsy;
  windownx = newnx;
  windowny = newny;
  return detectorrawsetbinning(binning); 
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_CHECK_OPEN();
  if (newbinning != 1)
    DETECTOR_ERROR("unable to set the detector binning.");
  binning = newbinning;  
  detectorrawsetpixnx((windownx + binning - 1) / binning);
  detectorrawsetpixny((windowny + binning - 1) / binning);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();
  DETECTOR_OK();
}

const char *
detectorrawgetvalue(const char *name)
{
  static char value[DETECTOR_STR_BUFFER_SIZE];
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  else if (strcmp(name, "cooler") == 0)
    snprintf(value, sizeof(value), "%s", "");
  else if (strcmp(name, "readmode") == 0)
    snprintf(value, sizeof(value), "%s", readmode);
  else if (strcmp(name, "windowsx") == 0)
    snprintf(value, sizeof(value), "%lu", windowsx);
  else if (strcmp(name, "windowsy") == 0)
    snprintf(value, sizeof(value), "%lu", windowsy);
  else if (strcmp(name, "windownx") == 0)
    snprintf(value, sizeof(value), "%lu", windownx);
  else if (strcmp(name, "windowny") == 0)
    snprintf(value, sizeof(value), "%lu", windowny);
  else if (strcmp(name, "binning") == 0)
    snprintf(value, sizeof(value), "%lu", binning);
  else
    snprintf(value, sizeof(value), "%s", detectorrawgetdatavalue(name));
  return value;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetcooler(const char *newcooler)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(newcooler, "") != 0)
    DETECTOR_ERROR("unable to set the cooler state.");
  DETECTOR_OK();
}

const char *
detectorrawgetcooler(void)
{
  return "";
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawfilterwheelmove(unsigned long newposition)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawfilterwheelupdatestatus(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawfilterwheelgetvalue(const char *name)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////
