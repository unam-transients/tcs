////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2010, 2011, 2012, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include <limits.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

static bool isopen = false;

static unsigned short softwaregain = 1;

static unsigned long pixnx = 0;
static unsigned long pixny = 0;
static unsigned long long pixnframe = 1;

static unsigned long pixi = 0;
static unsigned short *pix = NULL;

static unsigned long long cubepixi = 0;
static FILE *cubepixfp = NULL;

static unsigned long pixdataunbinnedwindowsx = 0;
static unsigned long pixdataunbinnedwindowsy = 0;
static unsigned long pixdataunbinnedwindownx = 0;
static unsigned long pixdataunbinnedwindowny = 0;

static double average = 0;
static double standarddeviation = 0;

////////////////////////////////////////////////////////////////////////

const char *
detectorrawgetdatavalue(const char *name)
{
  static char value[DETECTOR_STR_BUFFER_SIZE];
  if (strcmp(name, "softwaregain") == 0)
    snprintf(value, sizeof(value), "%u", (unsigned int)softwaregain);
  else if (strcmp(name, "amplifier") == 0)
    snprintf(value, sizeof(value), "%s", "conventional");
  else if (strcmp(name, "average") == 0)
    snprintf(value, sizeof(value), "%.2f", average);
  else if (strcmp(name, "standarddeviation") == 0)
    snprintf(value, sizeof(value), "%.2f", standarddeviation);
  else
    snprintf(value, sizeof(value), "%s", "");
  return value;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetisopen(bool newisopen)
{
  isopen = newisopen;
  DETECTOR_OK();
}

bool detectorrawgetisopen(void)
{
  return isopen;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawpixstart(void)
{
  pixi = 0;
  free(pix);
  pix = (unsigned short *)malloc(pixnx * pixny * sizeof(*pix));
  if (pix == 0)
    DETECTOR_ERROR("unable to allocate memory for the detector pixel values.");
  DETECTOR_OK();
}

const char *
detectorrawpixnext(const long *newpix, unsigned long n)
{
  for (unsigned long i = 0; i < n; ++i, ++pixi)
  {
    if (pixi == pixnx * pixny)
      DETECTOR_ERROR("too much pixel data.");
    if (newpix[i] < 0)
      pix[pixi] = 0;
    else if (newpix[i] / softwaregain > USHRT_MAX)
      pix[pixi] = USHRT_MAX;
    else
      pix[pixi] = newpix[i] / softwaregain;
  }
  DETECTOR_OK();
}

static unsigned long
hexvalue(char c)
{
  switch (c)
  {
  case '0':
  {
    return 0;
  }
  case '1':
  {
    return 1;
  }
  case '2':
  {
    return 2;
  }
  case '3':
  {
    return 3;
  }
  case '4':
  {
    return 4;
  }
  case '5':
  {
    return 5;
  }
  case '6':
  {
    return 6;
  }
  case '7':
  {
    return 7;
  }
  case '8':
  {
    return 8;
  }
  case '9':
  {
    return 9;
  }
  case 'a':
  {
    return 10;
  }
  case 'b':
  {
    return 11;
  }
  case 'c':
  {
    return 12;
  }
  case 'd':
  {
    return 13;
  }
  case 'e':
  {
    return 14;
  }
  case 'f':
  {
    return 15;
  }
  case 'A':
  {
    return 10;
  }
  case 'B':
  {
    return 11;
  }
  case 'C':
  {
    return 12;
  }
  case 'D':
  {
    return 13;
  }
  case 'E':
  {
    return 14;
  }
  case 'F':
  {
    return 15;
  }
  default:
  {
    return 0;
  }
  }
}

const char *
detectorrawpixnexthex(const char *newhexpix)
{
  unsigned long n = strlen(newhexpix) / 4;
  long newpix[n];
  for (unsigned long i = 0; i < n; ++i)
  {
    newpix[i] =
        (hexvalue(newhexpix[4 * i + 0]) << 12) +
        (hexvalue(newhexpix[4 * i + 1]) << 8) +
        (hexvalue(newhexpix[4 * i + 2]) << 4) +
        (hexvalue(newhexpix[4 * i + 3]) << 0);
  }
  return detectorrawpixnext(newpix, n);
}

const char *
detectorrawpixend(void)
{
  if (pixi < pixnx * pixny)
    DETECTOR_ERROR("too little pixel data.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetsoftwaregain(unsigned long newdetectorsoftwaregain)
{
  DETECTOR_CHECK_OPEN();
  softwaregain = newdetectorsoftwaregain;
  DETECTOR_OK();
}

unsigned long
detectorrawgetsoftwaregain(void)
{
  return softwaregain;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetpixnx(unsigned long nx)
{
  pixnx = nx;
  DETECTOR_OK();
}

const char *
detectorrawsetpixny(unsigned long ny)
{
  pixny = ny;
  DETECTOR_OK();
}

const char *
detectorrawsetpixnframe(unsigned long nframe)
{
  pixnframe = nframe;
  DETECTOR_OK();
}

unsigned long
detectorrawgetpixnx(void)
{
  return pixnx;
}

unsigned long
detectorrawgetpixny(void)
{
  return pixny;
}

unsigned long
detectorrawgetpixnframe(void)
{
  return pixnframe;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatistics(void)
{
  double s0 = 0;
  double s1 = 0;
  double s2 = 0;

  for (unsigned long iy = 0; iy < pixny; ++iy)
  {
    for (unsigned long ix = 0; ix < pixnx; ++ix)
    {
      double z = pix[iy * pixnx + ix];
      s0 += 1;
      s1 += z;
      s2 += z * z;
    }
  }
  if (s0 == 0)
  {
    average = 0;
    standarddeviation = 0;
  }
  else
  {
    double variance;
    average = s1 / s0;
    variance = (s2 / s0) - (s1 / s0) * (s1 / s0);
    if (variance >= 0)
      standarddeviation = sqrt(variance);
    else
      standarddeviation = 0;
  }
  DETECTOR_OK();
}

const char *
detectorrawsetpixdatawindow(unsigned long sx, unsigned long sy, unsigned long nx, unsigned long ny)
{
  pixdataunbinnedwindowsx = sx;
  pixdataunbinnedwindowsy = sy;
  pixdataunbinnedwindownx = nx;
  pixdataunbinnedwindowny = ny;
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

#define APPENDFITSDATA_ERROR(s)                                     \
  do                                                                \
  {                                                                 \
    if (dofork)                                                     \
    {                                                               \
      fprintf(stderr, "error: detectorrawappendfitsdata: %s\n", s); \
      exit(1);                                                      \
    }                                                               \
    else                                                            \
    {                                                               \
      DETECTOR_ERROR(s);                                            \
    }                                                               \
  } while (0)

static void
fputu16(FILE *fp, unsigned short u)
{
  fputc(u / 0x100, fp);
  fputc(u % 0x100, fp);
}

static void
fputs16(short s, FILE *fp)
{
  if (s >= 0)
    fputu16(fp, s);
  else
    fputu16(fp, 0x10000 + s);
}

const char *
detectorrawappendfitsdata(
    const char *partialfitsfilename, const char *finalfitsfilename, const char *latestfilename, const char *currentfilename,
    int dofork, double bscale, double bzero)
{
  // Open the temporary file before potentially forking in order to be
  // able to report an error to the parent.

  FILE *fp = fopen(partialfitsfilename, "ab");
  if (fp == NULL)
  {
    DETECTOR_ERROR("unable to open the partial FITS file.");
  }

  // Wait for any children, to prevent defunct processes.
  while (waitpid(-1, 0, WNOHANG) > 0)
    ;

  if (dofork)
  {
    pid_t pid = fork();
    if (pid == -1)
    {
      DETECTOR_ERROR("unable to fork.");
    }
    else if (pid != 0)
    {
      fclose(fp);
      DETECTOR_OK();
    }
  }

  unsigned long pixn = pixnx * pixny;
  for (unsigned long i = 0; i < pixn; ++i)
  {
    short s16 = floor(((double)pix[i] - bzero) / bscale);
    fputs16(s16, fp);
  }
  for (unsigned long i = (pixn * 2) % 2880; i % 2880 != 0; ++i)
    fputc(0, fp);

  if (fclose(fp) != 0)
    APPENDFITSDATA_ERROR("error writing the partial FITS file.");

  // Create the latest link, if requested.

  if (strcmp(latestfilename, "") != 0)
  {
    char tmplatestfilename[strlen(latestfilename) + strlen(".tmp") + 1];
    strcpy(tmplatestfilename, latestfilename);
    strcat(tmplatestfilename, ".tmp");
    unlink(tmplatestfilename);
    if (link(partialfitsfilename, tmplatestfilename) == -1)
    {
      unlink(tmplatestfilename);
      static char s[1024];
      sprintf(s, "unable to create a link to the latest file: %s.", strerror(errno));
      APPENDFITSDATA_ERROR(s);
    }
    if (rename(tmplatestfilename, latestfilename) == -1)
    {
      unlink(tmplatestfilename);
      static char s[1024];
      sprintf(s, "unable to rename the link to the latest file: %s.", strerror(errno));
      APPENDFITSDATA_ERROR(s);
    }
  }

  // Create the current link, if requested.

  if (strcmp(currentfilename, "") != 0)
  {
    char tmpcurrentfilename[strlen(currentfilename) + strlen(".tmp") + 1];
    strcpy(tmpcurrentfilename, currentfilename);
    strcat(tmpcurrentfilename, ".tmp");
    unlink(tmpcurrentfilename);
    if (link(partialfitsfilename, tmpcurrentfilename) == -1)
    {
      unlink(tmpcurrentfilename);
      static char s[1024];
      sprintf(s, "unable to create a link to the current file: %s.", strerror(errno));
      APPENDFITSDATA_ERROR(s);
    }
    if (rename(tmpcurrentfilename, currentfilename) == -1)
    {
      unlink(tmpcurrentfilename);
      static char s[1024];
      sprintf(s, "unable to rename the link to the current file: %s.", strerror(errno));
      APPENDFITSDATA_ERROR(s);
    }
  }

  // The final FITS file might be copied and deleted by
  // a file migration mechanism (e.g., rsync --remove-source-file).
  // Therefore, it is vital that we create it after we have created the
  // latest and current links.

  if (link(partialfitsfilename, finalfitsfilename) == -1)
    APPENDFITSDATA_ERROR("unable to create a link to the final FITS file.");
  if (unlink(partialfitsfilename) == -1)
    APPENDFITSDATA_ERROR("unable to unlink the temporary FITS file.");

  if (dofork)
    _exit(0);

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcubepixstart(const char *fitscubepixfilename)
{
  cubepixi = 0;
  if (cubepixfp != NULL)
    fclose(cubepixfp);
  cubepixfp = fopen(fitscubepixfilename, "wb");
  if (cubepixfp == NULL)
    DETECTOR_ERROR("unable to open file for the detector pixel values.");
  DETECTOR_OK();
}

const char *
detectorrawcubepixnext(const long *newpix, unsigned long n, double bzero, double bscale)
{
  unsigned long long pixn = pixnx * pixny * pixnframe;
  for (unsigned long i = 0; i < n; ++i, ++cubepixi)
  {
    if (cubepixi == pixn)
      DETECTOR_ERROR("too much pixel data.");
    unsigned short upix;
    if (newpix[i] < 0)
      upix = 0;
    else if (newpix[i] / softwaregain > USHRT_MAX)
      upix = USHRT_MAX;
    else
      upix = newpix[i] / softwaregain;
    short spix = floor(((double)upix - bzero) / bscale);
    fputs16(spix, cubepixfp);
  }
  DETECTOR_OK();
}

const char *
detectorrawcubepixend(void)
{
  unsigned long long pixn = pixnx * pixny * pixnframe;
  if (cubepixi < pixn)
    DETECTOR_ERROR("too little pixel data.");
  for (unsigned long i = (pixn * 2) % 2880; i % 2880 != 0; ++i)
    fputc(0, cubepixfp);
  fclose(cubepixfp);
  cubepixfp = NULL;
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////
