////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <qhyccd.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

static qhyccd_handle *handle;

static char description[DETECTOR_STR_BUFFER_SIZE] = "";

static double detectortemperature = 0;
static double housingtemperature = 0;
static double coolerpower = 0;
static double coolersettemperature = 0;
static const char *cooler = "";

static char readmode[DETECTOR_STR_BUFFER_SIZE] = "";
static uint32_t nreadmode;

static unsigned long fullnx = 0;
static unsigned long fullny = 0;
static unsigned long unbinnedwindowsx = 0;
static unsigned long unbinnedwindowsy = 0;
static unsigned long unbinnedwindownx = 0;
static unsigned long unbinnedwindowny = 0;

static unsigned long binning = 1;

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  fprintf(stderr, "detectorrawstart: initializing.\n");
  if (InitQHYCCDResource() != QHYCCD_SUCCESS)
    DETECTOR_ERROR("initialization failed.");
  fprintf(stderr, "detectorrawstart: finished initializing.\n");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawopen(char *identifier)
{
  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently open.");

  if (strcmp(identifier, "") == 0)
  {
    int ndetector;

    fprintf(stderr, "detectorrawopen: scanning.\n");
    ndetector = ScanQHYCCD();
    fprintf(stderr, "detectorrawopen: found %d detectors.\n", ndetector);
    if (ndetector == 0)
    {
      fprintf(stderr, "detectorrawopen: error: no detectors found.\n");
      exit(1);
    }
    fprintf(stderr, "detectorrawopen: finished scanning.\n");

    fprintf(stderr, "detectorrawopen: determining identifier.\n");
    for (int i = 0; i < ndetector; ++i)
    {
      char identifier[32] = "";
      if (GetQHYCCDId(i, identifier) != QHYCCD_SUCCESS)
      {
        fprintf(stderr, "detectorrawopen: error: unable to determine identifier of detector %d.\n", i);
        exit(1);
      }
      fprintf(stderr, "detectorrawopen: detector %d has an identifier of \"%s\".\n", i, identifier);
      char model[32] = "";
      if (GetQHYCCDModel(identifier, model) != QHYCCD_SUCCESS)
      {
        fprintf(stderr, "detectorrawopen: error: unable to determine model of detector %d.\n", i);
        exit(1);
      }
      fprintf(stderr, "detectorrawopen: detector %d has an model of \"%s\".\n", i, model);
    }
    fprintf(stderr, "detectorrawopen: finished determining identifier.\n");
    exit(0);
  }

  fprintf(stderr, "detectorrawopen: opening detector \"%s\".\n", identifier);
  handle = OpenQHYCCD(identifier);
  if (handle == NULL)
    DETECTOR_ERROR("unable to open detector.");

  {
    if (GetQHYCCDNumberOfReadModes(handle, &nreadmode) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine number of read modes.");
    fprintf(stderr, "detectorrawopen: %d read modes.\n", nreadmode);
    for (uint32_t i = 0; i < nreadmode; ++i)
    {
      char name[80] = "";
      if (GetQHYCCDReadModeName(handle, i, name) != QHYCCD_SUCCESS)
        DETECTOR_ERROR("unable to determine read mode name.");
      uint32_t nx, ny;
      if (GetQHYCCDReadModeResolution(handle, i, &nx, &ny) != QHYCCD_SUCCESS)
        DETECTOR_ERROR("unable to determine read mode resolution.");
      fprintf(stderr, "detectorrawopen: read mode mode %lu: %lu x %lu: \"%s\".\n", (unsigned long)i, (unsigned long)nx, (unsigned long)ny, name);
    }
  }

  snprintf(description, sizeof(description), "%s", identifier);

  if (SetQHYCCDReadMode(handle, 0) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set read mode.");

  if (SetQHYCCDStreamMode(handle, 0) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set single-frame mode.");

  if (InitQHYCCD(handle) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to initialize detector.");

  if (SetQHYCCDParam(handle, CONTROL_TRANSFERBIT, 16) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set 16-bit mode.");

  {
    uint32_t nx, ny, bpp;
    double detectorx, detectory, pixelx, pixely;
    if (GetQHYCCDChipInfo(handle, &detectorx, &detectory, &nx, &ny, &pixelx, &pixely, &bpp) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine detector parameters.");
    fullnx = nx;
    fullny = ny;
    fprintf(stderr, "detectorrawopen: fullnx = %lu fullny = %lu bpp = %lu.\n", (unsigned long)fullnx, (unsigned long)fullny, (unsigned long)bpp);
  }

  if (IsQHYCCDControlAvailable(handle, CONTROL_GAIN) != QHYCCD_SUCCESS)
  {
    fprintf(stderr, "detectorrawopen: unable to control gain.");
  }
  else
  {
    double min, max, step;
    if (GetQHYCCDParamMinMaxStep(handle, CONTROL_EXPOSURE, &min, &max, &step) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine detector exposure time values.");
    fprintf(stderr, "detectorrawopen: exposure time: min = %f max = %f step = %f.\n", min, max, step);

    fprintf(stderr, "detectorrawopen: setting detector exposure time.\n");
    if (SetQHYCCDParam(handle, CONTROL_EXPOSURE, 1.0 * 1e6) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set detector exposure time.");

    fprintf(stderr, "detectorrawopen: getting detector exposure time.\n");
    double value = GetQHYCCDParam(handle, CONTROL_EXPOSURE);
    fprintf(stderr, "detectorrawopen: detector exposure time = %f.\n", value / 1e6);
  }

  if (IsQHYCCDControlAvailable(handle, CONTROL_GAIN) != QHYCCD_SUCCESS)
  {
    fprintf(stderr, "detectorrawopen: unable to control gain.");
  }
  else
  {
    double min, max, step;
    if (GetQHYCCDParamMinMaxStep(handle, CONTROL_GAIN, &min, &max, &step) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine detector gain values.");
    fprintf(stderr, "detectorrawopen: gain: min = %f max = %f step = %f.\n", min, max, step);

    fprintf(stderr, "detectorrawopen: setting detectir gain.\n");
    if (SetQHYCCDParam(handle, CONTROL_GAIN, 30.0) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set detector gain.");

    fprintf(stderr, "detectorrawopen: getting detector gain.\n");
    double gain = GetQHYCCDParam(handle, CONTROL_GAIN);
    fprintf(stderr, "detectorrawopen: gain = %f.\n", gain);
  }

  if (IsQHYCCDControlAvailable(handle, CONTROL_OFFSET) != QHYCCD_SUCCESS)
  {
    fprintf(stderr, "detectorrawopen: unable to control offset.");
  }
  else
  {
    double min, max, step;
    if (GetQHYCCDParamMinMaxStep(handle, CONTROL_OFFSET, &min, &max, &step) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine detector offset values.");
    fprintf(stderr, "detectorrawopen: offset: min = %f max = %f step = %f.\n", min, max, step);

    fprintf(stderr, "detectorrawopen: setting detector offset.\n");
    if (SetQHYCCDParam(handle, CONTROL_OFFSET, 30.0) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set detector offset.");

    fprintf(stderr, "detectorrawopen: getting detector offset.\n");
    double offset = GetQHYCCDParam(handle, CONTROL_OFFSET);
    fprintf(stderr, "detectorrawopen: offset = %f.\n", offset);
  }

  if (IsQHYCCDControlAvailable(handle, CONTROL_SPEED) != QHYCCD_SUCCESS)
  {
    fprintf(stderr, "detectorrawopen: unable to control speed.");
  }
  else
  {
    double min, max, step;
    if (GetQHYCCDParamMinMaxStep(handle, CONTROL_SPEED, &min, &max, &step) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to determine speed values.");
    fprintf(stderr, "detectorrawopen: speed: min = %f max = %f step = %f.\n", min, max, step);

    fprintf(stderr, "detectorrawopen: setting speed.\n");
    if (SetQHYCCDParam(handle, CONTROL_SPEED, max) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set speed.");

    fprintf(stderr, "detectorrawopen: getting speed.\n");
    double speed = GetQHYCCDParam(handle, CONTROL_SPEED);
    fprintf(stderr, "detectorrawopen: speed = %f.\n", speed);
  }

  detectorrawsetisopen(true);
  coolersettemperature = 0.0;
  cooler = "off";
  return detectorrawsetunbinnedwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  if (CloseQHYCCD(handle) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to close detector.");
  handle = NULL;
  detectorrawsetisopen(false);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawreset(void)
{
  DETECTOR_CHECK_OPEN();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawmovefilterwheel(unsigned long position)
{
  DETECTOR_CHECK_OPEN();
  if (position != 0)
    DETECTOR_ERROR("unable to move the filter wheel.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawexpose(double exposuretime, const char *shutter)
{
  fprintf(stderr, "detectorrawexpose: starting.\n");

  DETECTOR_CHECK_OPEN();
  if (strcmp(shutter, "open") != 0 && strcmp(shutter, "closed") != 0)
    DETECTOR_ERROR("invalid shutter argument.");

  if (CancelQHYCCDExposingAndReadout(handle) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to cancel exposure.");

  if (SetQHYCCDParam(handle, CONTROL_EXPOSURE, exposuretime * 1e6) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("invalid exposure time.");

  if (ExpQHYCCDSingleFrame(handle) != QHYCCD_SUCCESS)
  {
    CancelQHYCCDExposingAndReadout(handle);
    DETECTOR_ERROR("unable to expose.");
  }

  fprintf(stderr, "detectorrawexpose: finished.\n");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  if (CancelQHYCCDExposingAndReadout(handle) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to cancel exposure.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool detectorrawgetreadytoberead(void)
{
  fprintf(stderr, "detectorrawgetreadytoberead: polling.\n");
  return GetQHYCCDExposureRemaining(handle) == 0;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawread(void)
{
  fprintf(stderr, "detectorrawread: starting.\n");

  DETECTOR_CHECK_OPEN();
  if (!detectorrawgetreadytoberead())
    DETECTOR_ERROR("the detector is not ready to be read.");

  uint32_t nbyte = GetQHYCCDMemLength(handle);
  if (nbyte == 0)
    DETECTOR_ERROR("the unable to determine data length.");
  fprintf(stderr, "detectorrawread: %lu bytes of data.\n", (unsigned long)nbyte);
  fprintf(stderr, "detectorrawread: %lu megabytes of data.\n", (unsigned long)(nbyte / 1024 / 1024));
  unsigned short *data = (unsigned short *)malloc(nbyte);
  memset(data, 0, nbyte);

  {
    fprintf(stderr, "detectorrawread: reading\n");
    uint32_t nx, ny, nchannel, bpp;
    if (GetQHYCCDSingleFrame(handle, &nx, &ny, &bpp, &nchannel, (uint8_t *)data) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to read exposure.");
    if (nx != detectorrawgetpixnx() || ny != detectorrawgetpixny())
      DETECTOR_ERROR("format does not match.");
    fprintf(stderr, "detectorrawread: %lu x %lu x %lu x %lu\n", (unsigned long)nx, (unsigned long)ny, (unsigned long)bpp, (unsigned long)nchannel);
  }

  unsigned long nx = detectorrawgetpixnx();
  unsigned long ny = detectorrawgetpixny();
  fprintf(stderr, "detectorrawread: %lu x %lu\n", (unsigned long)nx, (unsigned long)ny);
  for (unsigned long iy = 0; iy < ny; ++iy)
  {
    unsigned short *usbuf = data + iy * nx;
    long lbuf[nx];
    for (unsigned long ix = 0; ix < nx; ++ix)
      lbuf[ix] = usbuf[ix];
    detectorrawpixnext(lbuf, nx);
  }
  fprintf(stderr, "detectorrawread: finished.\n");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPEN();

  unsigned int ireadmode, igain, ioffset;

  if (sscanf(newreadmode, "%u-%u-%u", &ireadmode, &igain, &ioffset) != 3)
    DETECTOR_ERROR("invalid read mode.");

  if (SetQHYCCDReadMode(handle, ireadmode) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set read mode.");
  if (SetQHYCCDParam(handle, CONTROL_GAIN, igain) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set gain.");
  if (SetQHYCCDParam(handle, CONTROL_GAIN, ioffset) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set offset.");

  uint32_t nx, ny, bpp;
  double detectorx, detectory, pixelx, pixely;
  if (GetQHYCCDChipInfo(handle, &detectorx, &detectory, &nx, &ny, &pixelx, &pixely, &bpp) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to determine detector parameters.");
  fullnx = nx;
  fullny = ny;

  strcpy(readmode, newreadmode);

  return detectorrawsetunbinnedwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetunbinnedwindow(unsigned long newsx, unsigned long newsy, unsigned long newnx, unsigned long newny)
{
  DETECTOR_CHECK_OPEN();
  if (newsx == 0 && newnx == 0)
  {
    newnx = fullnx;
  }
  if (newsy == 0 && newny == 0)
  {
    newny = fullny;
  }
  if (SetQHYCCDResolution(handle, newsx, newsy, newnx, newny) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set window.");
  unbinnedwindowsx = newsx;
  unbinnedwindowsy = newsy;
  unbinnedwindownx = newnx;
  unbinnedwindowny = newny;
  return detectorrawsetbinning(1);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_CHECK_OPEN();
  if (SetQHYCCDBinMode(handle, newbinning, newbinning) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set binning.");
  binning = newbinning;
  detectorrawsetpixnx((unbinnedwindownx + binning - 1) / binning);
  detectorrawsetpixny((unbinnedwindowny + binning - 1) / binning);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();

  double value;

  value = GetQHYCCDParam(handle, CONTROL_CURTEMP);
  if (value != QHYCCD_ERROR)
  {
    fprintf(stderr, "detectorrawupdatestatus: detector temperature is %+.1f C.\n", value);
    detectortemperature = value;
  }

  value = GetQHYCCDParam(handle, CONTROL_COOLER);
  if (value != QHYCCD_ERROR)
  {
    fprintf(stderr, "detectorrawupdatestatus: cooler set tempertaure is %+.1f C.\n", value);
    coolersettemperature = value;
  }

  value = GetQHYCCDParam(handle, CONTROL_CURPWM);
  if (value != QHYCCD_ERROR)
    coolerpower = value / 255;

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawgetvalue(const char *name)
{
  static char value[DETECTOR_STR_BUFFER_SIZE];
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  else if (strcmp(name, "detectortemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", detectortemperature);
  else if (strcmp(name, "housingtemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", housingtemperature);
  else if (strcmp(name, "coolersettemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", coolersettemperature);
  else if (strcmp(name, "coolerpower") == 0)
    snprintf(value, sizeof(value), "%.2f", coolerpower);
  else if (strcmp(name, "cooler") == 0)
    snprintf(value, sizeof(value), "%s", cooler);
  else if (strcmp(name, "readmode") == 0)
    snprintf(value, sizeof(value), "%s", readmode);
  else if (strcmp(name, "unbinnedwindowsx") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowsx);
  else if (strcmp(name, "unbinnedwindowsy") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowsy);
  else if (strcmp(name, "unbinnedwindownx") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindownx);
  else if (strcmp(name, "unbinnedwindowny") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowny);
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

  if (IsQHYCCDControlAvailable(handle, CONTROL_COOLER) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set cooler set temperature.");
  if (IsQHYCCDControlAvailable(handle, CONTROL_MANULPWM) != QHYCCD_SUCCESS)
    DETECTOR_ERROR("unable to set cooler power.");

  if (strcmp(newcooler, "on") == 0)
  {
    if (ControlQHYCCDTemp(handle, coolersettemperature) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set cooler to on.");
    if (SetQHYCCDParam(handle, CONTROL_MANULPWM, 128.0) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set cooler to 50%.");
    cooler = "on";
    DETECTOR_OK();
  }
  else if (strcmp(newcooler, "off") == 0)
  {
    if (SetQHYCCDParam(handle, CONTROL_MANULPWM, 0.0) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set cooler to off.");
    cooler = "off";

    DETECTOR_OK();
  }
  else if (strcmp(newcooler, "following") == 0)
  {
    DETECTOR_ERROR("cooler following is not supported.");
  }
  else
  {
    char *end;
    coolersettemperature = strtod(newcooler, &end);
    if (*end != 0)
      DETECTOR_ERROR("invalid arguments.");
    if (ControlQHYCCDTemp(handle, coolersettemperature) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set cooler to on.");
    if (ControlQHYCCDTemp(handle, coolersettemperature) != QHYCCD_SUCCESS)
      DETECTOR_ERROR("unable to set cooler to on.");
    cooler = "on";
    DETECTOR_OK();
  }
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
