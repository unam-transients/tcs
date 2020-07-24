////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: detectorh2rg.cxx 3538 2020-04-23 20:31:00Z Alan $

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

static char identifierbuffer[DETECTOR_STR_BUFFER_SIZE];

const char *
detectorrawopen(char *identifier)
{
  if (detectoropened)
    DETECTOR_ERROR("a detector is currently opened.");

  if (strcmp(identifier, "C2") != 0 && strcmp(identifier, "C3") != 0)
    return "invalid H2RG identifier.";
  snprintf(identifierbuffer, sizeof(identifierbuffer), "%s", identifier);
  
  char description[DETECTOR_STR_BUFFER_SIZE];
  snprintf(description, sizeof(description), "H2RG (%s)", identifier);    
  detectorrawsetdescription(description);
  
  detectoropened = true;
  
  return detectorrawsetwindow(0, 0, 2048, 2048);
}

const char *
detectorrawclose(void)
{
  detectoropened = false;
  detectorrawsetdescription("");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetcooler(const char *state)
{
  DETECTOR_CHECK_OPENED();
  if (strcmp(state, "") != 0)
    DETECTOR_ERROR("unable to set the cooler state.");
  DETECTOR_OK();
}

const char *
detectorrawmovefilterwheel(long position)
{
  DETECTOR_CHECK_OPENED();
  if (position != 0)
    DETECTOR_ERROR("unable to move the filter wheel.");
  DETECTOR_OK();
}

static char *rawfitspath;

const char *
detectorrawexpose(double exposuretime, const char *shutter)
{
  DETECTOR_CHECK_OPENED();
  rawfitspath = getenv("RAWFITSPATH");
  if (rawfitspath == NULL)
    DETECTOR_ERROR("RAWFITSPATH is not set in the environment.");
  unlink(rawfitspath);
  pid_t childpid = fork();
  if (childpid == 0) {
    char exposuretimearg[DETECTOR_STR_BUFFER_SIZE];
    snprintf(exposuretimearg, sizeof(exposuretimearg), "%.3f", exposuretime);
    execlp("h2rgexpose", "h2rgexpose", identifierbuffer, rawfitspath, exposuretimearg, detectorreadmode, NULL);
  } else if (childpid < 0) {
    DETECTOR_ERROR("fork() failed.");
  }
  DETECTOR_OK();
}

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

bool
detectorrawgetreadytoberead(void)
{
  if (!detectoropened)
    return false;
  struct stat buf;
  return stat(rawfitspath, &buf) == 0;
}

const char *
detectorrawread()
{
  DETECTOR_CHECK_OPENED();
  if (!detectorrawgetreadytoberead())
    DETECTOR_ERROR("the detector is not ready to be read.");

  fitsfile *ffp;         
  int status = 0;

  fits_open_file(&ffp, rawfitspath, READONLY, &status);
      
  int rank;
  fits_get_img_dim(ffp, &rank,  &status);
  long dimension[rank];
  fits_get_img_size(ffp, sizeof(dimension) / sizeof(*dimension), dimension, &status);  
  if (rank != 2 || dimension[0] != detectornx || dimension[1] != detectorny)
    DETECTOR_ERROR("the raw FITS file does not have the expected structure.");
  
  float *buf = (float *) malloc(detectornx * detectorny * sizeof(*buf));
  if (buf == NULL)
    DETECTOR_ERROR("malloc() failed.");

  long fpixel[] = {1, 1};
  fits_read_pix(ffp, TFLOAT, fpixel, detectornx * detectorny, NULL, buf, NULL, &status);
  fits_close_file(ffp, &status);
  if (status)
    DETECTOR_ERROR("unable to read the raw FITS file.");

  for (int iy = 0; iy < detectorny; ++iy)
    for (int ix = 0; ix < detectornx; ++ix)
      detectorpix[iy * detectornx + ix] = floor(buf[iy * detectornx + ix]);
      
  free(buf);

  detectorupdatestatistics();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

static char readmodebuffer[DETECTOR_STR_BUFFER_SIZE];

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPENED();
  char *s;
  long l = strtol(newreadmode, &s, 10);
  if (strcmp(newreadmode, "") == 0 || *s != 0 || l < 1)
    DETECTOR_ERROR("invalid readmode.");
  snprintf(readmodebuffer, sizeof(readmodebuffer), "%ld", l);
  detectorreadmode = readmodebuffer; 
  DETECTOR_OK();
}

const char *
detectorrawupdatestatusreadmode(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetwindow(long newsx, long newsy, long newnx, long newny)
{
  DETECTOR_CHECK_OPENED();
  if (newsx != 0 && newsy != 0 && newnx != 2048 && newny != 2048)
    DETECTOR_ERROR("unable to set the detector window.");
  detectorwindowsx = newsx;
  detectorwindowsy = newsy;
  detectorwindownx = newnx;
  detectorwindowny = newny;
  return detectorallocatepix();
}

const char *
detectorrawsetbinning(long newbinning)
{
  DETECTOR_CHECK_OPENED();
  if (newbinning != 1)
    DETECTOR_ERROR("unable to set the detector binning.");
  detectorbinning = newbinning;  
  detectornx = 2048 / detectorbinning;
  detectorny = 2048 / detectorbinning;
  return detectorallocatepix();
}

const char *
detectorrawupdatestatuswindowandbinning(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatusdetectortemperature(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatushousingtemperature(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatuscoolerstate(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatuscoolersettemperature(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatuscoolerpower(void)
{
  DETECTOR_CHECK_OPENED();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////
