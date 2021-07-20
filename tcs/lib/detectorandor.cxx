////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: detectordummy.cxx 3542 2020-05-16 00:42:23Z Alan $

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
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

static char description[DETECTOR_STR_BUFFER_SIZE] = "";
static double detectortemperature = 0;
static double housingtemperature = 0;
static double coolersettemperature = 0;
static const char *cooler = "";

static int iadc;
static int iamplifier;
static int ivsspeed;
static int ihsspeed;
static int igain;
static int emgain;
static int flipped;

static char amplifier[DETECTOR_STR_BUFFER_SIZE] = "";
static char vsspeed[DETECTOR_STR_BUFFER_SIZE] = "";
static char hsspeed[DETECTOR_STR_BUFFER_SIZE] = "";

static char readmode[DETECTOR_STR_BUFFER_SIZE] = "";

static unsigned long fullnx = 0;
static unsigned long fullny = 0;
static unsigned long windowsx = 0;
static unsigned long windowsy = 0;
static unsigned long windownx = 0;
static unsigned long windowny = 0;

static unsigned long binning = 1;

////////////////////////////////////////////////////////////////////////

#include "atmcdLXd.h"

////////////////////////////////////////////////////////////////////////

static char *
msg(const char *fmt, ...)
{
  static char s[1024];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(s, sizeof(s), fmt, ap);
  va_end(ap);
  return s;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const static void
fprintbits(FILE *fp, const char *name, unsigned int u)
{
  fprintf(fp, "%s: set bits are", name);
  for (int i = 0; i < 32; ++i) {
    if ((u >> i) & 1)
      fprintf(fp, " %d", i);
  }
  fprintf(fp, "\n");
}

const char *
detectorrawopen(char *identifier)
{
  unsigned int status;

  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently open");

  char etcdir[] = "/usr/local/etc/andor";
  status = Initialize(etcdir);
  if (status != DRV_SUCCESS) {
    DETECTOR_ERROR(msg("unable to initialize detector (status is %u).", status));
  }
  
  sleep(2);
  
  AndorCapabilities cap;
  cap.ulSize = sizeof(cap);
  status = GetCapabilities(&cap);
  if (status != DRV_SUCCESS)
     DETECTOR_ERROR(msg("GetCapabilities failed (status is %u).", status));
  const char *cameratype;
  if (cap.ulCameraType == 1)
    cameratype = "Andor iXon";
  else if (cap.ulCameraType == 11)
    cameratype = "Andor Luca";
  else if (cap.ulCameraType == 13)
    cameratype = "Andor iKon";
  else if (cap.ulCameraType == 21)
    cameratype = "Andor iXon Ultra";
  else if (cap.ulCameraType == 21)
    cameratype = "Andor Ikon XL";
  else if (cap.ulCameraType == 31)
    cameratype = "Andor Ikon LR";
  else
    cameratype = "Andor";

  char model[DETECTOR_STR_BUFFER_SIZE];
  status = GetHeadModel(model);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get head model (status is %u).", status));  
  
  int serialnumber;
  status = GetCameraSerialNumber(&serialnumber);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get serial number (status is %u).", status));

  snprintf(description, sizeof(description), "%s %s (%d)", cameratype, model, serialnumber);    
  
  coolersettemperature = 25.0;
  cooler = "off";
  status = CoolerOFF();
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to switch off cooler (status is %u).", status));
    
  int nx;
  int ny;
  status = GetDetector(&nx, &ny);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get detector size (status is %u).", status));
  fullnx = nx;
  fullny = ny;  
    
  status = SetReadMode(4);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to select raw read mode (status is %u).", status));

  status = SetAcquisitionMode(1);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to select raw acquisition mode (status is %u).", status));

  status = SetShutter(1,0,50,50);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to select raw shutter mode (status is %u).", status));

  detectorrawsetisopen(true);
  
  {
    FILE *fp = fopen("/tmp/andor.txt", "w");
    unsigned int status;

    int nchannel;
    status = GetNumberADChannels(&nchannel);
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("GetNumberADChannels failed (status is %u).", status));  
    fprintf(fp, "number of AD channels = %d\n", nchannel);
    
    int namp;
    status = GetNumberAmp(&namp);
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("GetNumberAmp failed (status is %u).", status));  
    fprintf(fp, "number of amplifiers = %d\n", namp);
    
    int npreampgain;
    status = GetNumberPreAmpGains(&npreampgain);
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("GetNumberPreAmpGains failed (status is %u).", status));  
    fprintf(fp, "number of preamp gains = %d\n", npreampgain);
    
    for (int iamp = 0; iamp < namp; ++iamp) {
      char desc[256];
      status = GetAmpDesc(iamp, desc, sizeof(desc));
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("GetAmpDesc failed (status is %u).", status));
      fprintf(fp, "amplifier %d = %s\n", iamp, desc);
      status = IsReadoutFlippedByAmplifier(iamp, &flipped);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("GetReadoutFlippedByAmplifier failed (status is %u).", status));
      fprintf(fp, "amplifier %d readout flipped = %d\n", iamp, flipped);
    }
    
    for (int ichannel = 0; ichannel < nchannel; ++ichannel) {

      int bits;
      status = GetBitDepth(ichannel, &bits);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("GetBitDepth failed (status is %u).", status));  
      fprintf(fp, "bit depth of AD channel %d = %d\n", ichannel, bits);

      for (int itype = 0; itype < 2; ++itype) {

        const char *type;
        if (itype == 0)
          type = "EM";
        else
          type = "conventional";

        int nhsspeed;
        status = GetNumberHSSpeeds(ichannel, itype, &nhsspeed);
        if (status != DRV_SUCCESS)
          DETECTOR_ERROR(msg("GetNumberHSSpeeds failed (status is %u).", status));  
        fprintf(fp, "number of HS speeds for AD channel %d (%s) = %d\n", ichannel, type, nhsspeed);

        for (int ihsspeed = 0; ihsspeed < nhsspeed; ++ihsspeed) {
          float speed;
          status = GetHSSpeed(ichannel, itype, ihsspeed, &speed);
          if (status != DRV_SUCCESS)
            DETECTOR_ERROR(msg("GetHSSpeed failed (status is %u).", status));  
          fprintf(fp, "HS speed %d for AD channel %d (%s) = %f\n", ihsspeed, ichannel, type, speed);
          
          int available;
          for (int ipreampgain = 0; ipreampgain < npreampgain; ++ipreampgain) {
            status = IsPreAmpGainAvailable(ichannel, itype, ihsspeed, ipreampgain, &available);
            if (status != DRV_SUCCESS)
              DETECTOR_ERROR(msg("IsPreAmpGainAvailable failed (status is %u).", status));
            if (available) {
              float gain;
              status = GetPreAmpGain(ipreampgain, &gain);
              if (status != DRV_SUCCESS)
                DETECTOR_ERROR(msg("GetPreampGain failed (status is %u).", status));
              fprintf(fp, "gain %d is available = %f\n", ipreampgain, gain);
            } else {
              fprintf(fp, "gain %d is not available\n", ipreampgain);
            }
          }
    
        }

      }

    }
    
    int nvsspeed;
    status = GetNumberVSSpeeds(&nvsspeed);
    if (status != DRV_SUCCESS)
       DETECTOR_ERROR(msg("GetNumberVSSpeeds failed (status is %u).", status));  
    fprintf(fp, "number of VS speeds = %d\n", nvsspeed);

    for (int ivsspeed = 0; ivsspeed < nvsspeed; ++ivsspeed) {
      float speed;
      status = GetVSSpeed(ivsspeed, &speed);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("GetVSSpeed failed (status is %u).", status));  
      fprintf(fp, "VS speed %d = %f ns\n", ivsspeed, speed * 1e3);
    }
    
    {
      float speed;
      int ivsspeed;
      status = GetFastestRecommendedVSSpeed(&ivsspeed, &speed);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("GetFastestRecommendedVSSpeed failed (status is %u).", status));  
      fprintf(fp, "fastest recommended VS speed = %d %f ns\n", ivsspeed, speed * 1e3);
    }    

    fprintbits(fp, "ulAcqModes", cap.ulAcqModes);
    fprintbits(fp, "ulReadModes", cap.ulReadModes);
    fprintbits(fp, "ulFTReadModes", cap.ulFTReadModes);
    fprintbits(fp, "ulTriggerModes", cap.ulTriggerModes);
    fprintf(fp, "ulCameraType = %u\n", cap.ulCameraType);
    if (cap.ulCameraType == 21)
      fprintf(fp, "Camera is Andor iXon Ultra\n");
    else
      fprintf(fp, "Camera is other.\n");
    fprintbits(fp, "ulPixelMode", cap.ulPixelMode);
    fprintbits(fp, "ulSetFunctions", cap.ulSetFunctions);
    fprintbits(fp, "ulGetFunctions", cap.ulGetFunctions);
    
    // Select EMCCD register
    status = SetOutputAmplifier(0);
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("SetOutputAmplifier failed (status is %u).", status));
    
    for (int imode = 0; imode <= 3; ++imode) {
      status = SetEMGainMode(imode);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("SetEMGainMode failed (status is %u).", status));
      int low;
      int high;
      status = GetEMGainRange(&low, &high);
      fprintf(fp, "gain range for EM mode %d is %d to %d\n", imode, low, high);
    }

    // Select EMCCD register
    status = SetEMAdvanced(1);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("SetEMAdvanced failed (status is %u).", status));

    for (int imode = 0; imode <= 3; ++imode) {
      status = SetEMGainMode(imode);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("SetEMGainMode failed (status is %u).", status));
      int low;
      int high;
      status = GetEMGainRange(&low, &high);
      fprintf(fp, "gain range for EM mode %d (advanced) is %d to %d\n", imode, low, high);
    }

    // Select convencional CCD register
    status = SetOutputAmplifier(1);
      if (status != DRV_SUCCESS)
        DETECTOR_ERROR(msg("SetOutputAmplifier failed (status is %u).", status));

    fclose(fp);
  }

  return detectorrawsetwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  detectorrawsetisopen(false);
  ShutDown();
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
  unsigned int status;

  DETECTOR_CHECK_OPEN();

  if (strcmp(shutter, "open") != 0 && strcmp(shutter, "closed") != 0)
    DETECTOR_ERROR("invalid shutter argument");

  status = SetExposureTime(exposuretime);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to set exposure time (status is %u).", status));
    
  if (strcmp(shutter, "open") == 0)
    status = SetShutter(0, 0, 50, 50);
  else 
    status = SetShutter(0, 2, 50, 50);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to set shutter (status is %u).", status));
    
  status = StartAcquisition();
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to start acquisition (status is %u).", status));

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  unsigned int status;
  status = AbortAcquisition();
  if (status != DRV_SUCCESS && status != DRV_IDLE)
    DETECTOR_ERROR(msg("unable to abort acquisition (status is %u).", status));    
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool
detectorrawgetreadytoberead(void)
{
  int status;
  GetStatus(&status);
  return status != DRV_ACQUIRING;
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

  unsigned short pix[ny * nx];
  unsigned int status;
  status = GetAcquiredData16(pix, nx * ny);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get pixel data (nx is %lu ny is %lu status is %u).", nx, ny, status));
  
  detectorrawpixstart();
  if (flipped) {
    for (unsigned long iy = 0; iy < ny; ++iy) {
      for (unsigned long ix = 0; ix < nx; ++ix) {
        long lpix = pix[iy * nx + (nx - 1 - ix)];
        detectorrawpixnext(&lpix, 1);
      }
    }
  } else {
    for (unsigned long iy = 0; iy < ny; ++iy) {
      for (unsigned long ix = 0; ix < nx; ++ix) {
        long lpix = pix[iy * nx - ix];
        detectorrawpixnext(&lpix, 1);
      }
    }
  }
  detectorrawpixend();
  
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

static const char *
setreadmodehelper(int iadc, int iamplifier, int ivsspeed, int ihsspeed, int igain, int emgain)
{
  int status;

  status = SetADChannel(iadc);
  if (status != DRV_SUCCESS)
    return "invalid ADC index.";
  
  status = SetOutputAmplifier(iamplifier);
  if (status != DRV_SUCCESS)
    return "invalid amplifier index.";
  
  status = SetVSSpeed(ivsspeed);
  if (status != DRV_SUCCESS)
    return "invalid VS speed index.";
  
  status = SetHSSpeed(iamplifier, ihsspeed);
  if (status != DRV_SUCCESS)
    return "invalid HS speed index.";
  
  status = SetPreAmpGain(igain);
  if (status != DRV_SUCCESS)
    return "invalid gain index";

  if (emgain != 0) {
    // 3 = Real EM gain
    status = SetEMGainMode(3);
    if (status != DRV_SUCCESS)
      return "unable to select EM gain mode.";
    status = SetEMAdvanced(1);
    if (status != DRV_SUCCESS)
      return "unable to select EM advanced mode.";
    status = SetEMCCDGain(emgain);
    if (status != DRV_SUCCESS)
      return "invalid EMCCD gain.";
  }
  
  return "";
}

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPEN();
  
  int newiadc;
  int newiamplifier;
  int newivsspeed;
  int newihsspeed;
  int newigain;
  int newemgain;
  
  if (sscanf(newreadmode, "%d-%d-%d-%d-%d-%d", 
    &newiadc, &newiamplifier, &newivsspeed, &newihsspeed, &newigain, &newemgain) != 6)
    DETECTOR_ERROR("invalid detector read mode.");

  const char *msg = 
    setreadmodehelper(newiadc, newiamplifier, newivsspeed, newihsspeed, newigain, newemgain);
  
  if (strcmp(msg, "") != 0) {
    setreadmodehelper(iadc, iamplifier, ivsspeed, ihsspeed, igain, emgain);
    DETECTOR_ERROR(msg);
  }

  iadc       = newiadc;
  iamplifier = newiamplifier;
  ivsspeed   = newivsspeed;
  ihsspeed   = newihsspeed;
  igain      = newigain;
  emgain     = newemgain;

  strcpy(readmode, newreadmode);

  int status;  
  status = GetAmpDesc(iamplifier, amplifier, sizeof(amplifier));
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR("unable to determine amplifier.");
  if(strcmp(amplifier, "Conventional") == 0)
    snprintf(amplifier, sizeof(amplifier), "conventional");
  if(strcmp(amplifier, "Electron Multiplying") == 0)
    snprintf(amplifier, sizeof(amplifier), "EM");
    
  float speed;
  
  status = GetVSSpeed(ivsspeed, &speed);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR("unable to determine VS speed.");
  snprintf(vsspeed, sizeof(vsspeed), "%.0f ns", speed * 1e3);
  status = GetHSSpeed(0, iamplifier, ihsspeed, &speed);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR("unable to determine HS speed.");
  if (speed >= 1)
    snprintf(hsspeed, sizeof(hsspeed), "%.1f MHz", speed);
  else
    snprintf(hsspeed, sizeof(hsspeed), "%.0f kHz", speed * 1e3);

  status = GetEMCCDGain(&emgain);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR("unable to determine EM gain.");
  
  status = IsReadoutFlippedByAmplifier(iamplifier, &flipped);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR("unable to determine in readout is flipped.");
  
  DETECTOR_OK();
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
  windowsx = newsx;
  windowsy = newsy;
  windownx = newnx;
  windowny = newny;
  return detectorrawsetbinning(1); 
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  unsigned int status;  
  DETECTOR_CHECK_OPEN();
  
  int maxbinningx;
  status = GetMaximumBinning(4, 0, &maxbinningx);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get maximum x binning (status is %u).", status));

  int maxbinningy;
  status = GetMaximumBinning(4, 1, &maxbinningy);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to get maximum x binning (status is %u).", status));
    
  unsigned int maxbinning;
  if (maxbinningx >= maxbinningy)
    maxbinning = maxbinningy;
  else
    maxbinning = maxbinningx;
    
  if (newbinning > maxbinning)
    DETECTOR_ERROR(msg("requested binning (%d) exceeds maximum supported binning (%d)", newbinning, maxbinning));

  status = SetImage(newbinning, newbinning, windowsx + 1, windowsx + windownx, windowsy + 1, windowsy + windowny);
  if (status != DRV_SUCCESS)
    DETECTOR_ERROR(msg("unable to set detector window and binning (status is %u).", status));
  
  binning = newbinning;
  
  detectorrawsetpixnx(windownx / binning);
  detectorrawsetpixny(windowny / binning);

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();
  
  float temperature;
  unsigned int status;
  status = GetTemperatureF(&temperature);
  if (status == DRV_NOT_INITIALIZED) {
    DETECTOR_ERROR("detector is not initialized.");
  } else if (status == DRV_TEMP_OFF) {
    cooler = "off";
    detectortemperature = temperature;
  } else if (status == DRV_TEMP_STABILIZED) {
    cooler = "stabilized";
  } else if (status == DRV_TEMP_NOT_REACHED) {
    cooler = "cooling";
  } else if (status == DRV_TEMP_DRIFT) {
    cooler = "drifting";
  } else if (status == DRV_TEMP_NOT_STABILIZED) {
    cooler = "stabilizing";
  } else {
    cooler = "other";
  }
  detectortemperature = temperature;

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
  else if (strcmp(name, "coolersettemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", coolersettemperature);
  else if (strcmp(name, "cooler") == 0)
    snprintf(value, sizeof(value), "%s", cooler);
  else if (strcmp(name, "readmode") == 0)
    snprintf(value, sizeof(value), "%s", readmode);
  else if (strcmp(name, "adc") == 0)
    snprintf(value, sizeof(value), "%d", iadc);
  else if (strcmp(name, "amplifier") == 0)
    snprintf(value, sizeof(value), "%s", amplifier);
  else if (strcmp(name, "vsspeed") == 0)
    snprintf(value, sizeof(value), "%s", vsspeed);
  else if (strcmp(name, "hsspeed") == 0)
    snprintf(value, sizeof(value), "%s", hsspeed);
  else if (strcmp(name, "gain") == 0)
    snprintf(value, sizeof(value), "%d", igain);
  else if (strcmp(name, "emgain") == 0)
    snprintf(value, sizeof(value), "%d", emgain);
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
  if (strcmp(newcooler, "off") == 0) {
    unsigned int status;
    status = CoolerOFF();
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("unable to switch off cooler (status is %u).", status));
    cooler = "off";
    DETECTOR_OK();
  } else {
    if (strcmp(newcooler, "following") == 0) {
      detectorrawupdatestatus();
      coolersettemperature = housingtemperature;
    } else if (strcmp(newcooler, "on") != 0) {
      char *end;
      double newcoolersettemperature = strtod(newcooler, &end);
      if (*end != 0)
        DETECTOR_ERROR("invalid cooler state");
      newcoolersettemperature = rint(newcoolersettemperature);
      coolersettemperature = newcoolersettemperature;      
      newcooler = "on";
    }
    unsigned int status;
    status = SetTemperature((int) coolersettemperature);
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("unable to set cooler set temperature (status is %u).", status));
    status = CoolerON();
    if (status != DRV_SUCCESS)
      DETECTOR_ERROR(msg("unable to switch on cooler (status is %u).", status));
    cooler = newcooler;
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
