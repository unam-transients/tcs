////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2011, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include "focuser.h"

////////////////////////////////////////////////////////////////////////

#if HAVE_LIBFLI

#include "libfli.h"

#define CHECK_FLI_CALL(f,e) \
  do { \
    if ((f) != 0) \
      FOCUSER_ERROR(e); \
  } while (0)

static flidev_t device = -1;

static const char *
opendevice(flidev_t *device, flidomain_t domain, const char *identifier)
{
  for (int i = 0; i < 10; ++i) {
    *device = FLI_INVALID_DEVICE;
    char name[FOCUSER_STR_BUFFER_SIZE];
    snprintf(name, sizeof(name), "/dev/fliusb%x", i);
    if (FLIOpen(device, name, domain) != 0) {
      *device = FLI_INVALID_DEVICE;
      continue;
    }
    if (strcmp(identifier, "first") == 0)
      break;
    char serialstring[FOCUSER_STR_BUFFER_SIZE];
    CHECK_FLI_CALL(
      FLIGetSerialString(*device, serialstring, sizeof(serialstring)),
      "unable to determine the serial number of a device."
    );
    if (strcmp(identifier, serialstring) == 0)
      break;
    CHECK_FLI_CALL(
      FLIClose(*device),
      "unable to close a device."
    );
    *device = FLI_INVALID_DEVICE;
  }
  if (*device == FLI_INVALID_DEVICE)
    FOCUSER_ERROR("unable to open device.");
  return "ok";
}

#endif

////////////////////////////////////////////////////////////////////////

const char *
focuserrawopen(char *identifier)
{
#if HAVE_LIBFLI
  //FLISetDebugLevel(NULL, FLIDEBUG_ALL);

  if (focuseropened)
    FOCUSER_ERROR("an focuser is currently opened.");
  
  { 
    const char *result = opendevice(&device, FLIDEVICE_FOCUSER|FLIDOMAIN_USB, identifier);
    if (strcmp(result, "ok") != 0)
      return result;
    focuseropened = true;
  }

  char modelstring[FOCUSER_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetModel(device, modelstring, sizeof(modelstring)),
    "unable to determine the focuser model."
  );
  if (strcmp(modelstring, "DF-2") == 0) {
    strcpy(modelstring, "DF2");
  }

  char serialstring[FOCUSER_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetSerialString(device, serialstring, sizeof(serialstring)),
    "unable to determine the serial number of the focuser."
    );

  static char descriptionbuffer[FOCUSER_STR_BUFFER_SIZE];
  snprintf(descriptionbuffer, sizeof(descriptionbuffer), "FLI %s (%s)", modelstring, serialstring);
  focuserdescription = descriptionbuffer;
  
  focuserminposition = 0;
  CHECK_FLI_CALL(
    FLIGetFocuserExtent(device, &focusermaxposition),
    "unable to determine the focuser maximum position."
  );
  pid_t forkpid = fork();
  if (forkpid == -1)
    FOCUSER_ERROR("unable to fork to initialize the focuser.");
  if (forkpid == 0) {
    CHECK_FLI_CALL(
      FLIHomeFocuser(device),
      "unable to initialize the focuser."
    );
    exit(0);
  }

  FOCUSER_OK();

#else
  FOCUSER_ERROR("not compiled with support for FLI devices.");
#endif

}

const char *
focuserrawclose(void)
{
#if HAVE_LIBFLI
  focuserdescription = "";
  focuseropened = false;
  CHECK_FLI_CALL(
    FLIClose(device),
    "unable to close the focuser."
  );
  FOCUSER_OK();
#else
  FOCUSER_ERROR("not compiled with support for FLI devices.");
#endif
}

const char *
focuserrawmove(long position)
{
#if HAVE_LIBFLI
  FOCUSER_CHECK_OPENED();
  long initialposition;
  CHECK_FLI_CALL(
    FLIGetStepperPosition(device, &initialposition),
    "unable to determine the focuser position"
  );
  pid_t forkpid = fork();
  if (forkpid == -1)
    FOCUSER_ERROR("unable to fork to set the focuser position.");
  if (forkpid == 0) {
    CHECK_FLI_CALL(
      FLIStepMotor(device, position - initialposition),
      "unable to set the focuser position"
    );
    exit(0);
  }
  FOCUSER_OK();
#else
  FOCUSER_ERROR("not compiled with support for FLI devices.");
#endif
}

const char *
focusersetposition(long position)
{
#if HAVE_LIBFLI
  FOCUSER_ERROR("unable to set the focuser position");
#else
  FOCUSER_ERROR("not compiled with support for FLI devices.");
#endif
}

const char *
focuserrawupdateposition(void)
{
#if HAVE_LIBFLI
  FOCUSER_CHECK_OPENED();
  CHECK_FLI_CALL(
    FLIGetStepperPosition(device, &focuserposition),
    "unable to determine the focuser position."
  );
  FOCUSER_OK();
#else
  FOCUSER_ERROR("not compiled with support for FLI devices.");
#endif
}
