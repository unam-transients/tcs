////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: detector.h 3542 2020-05-16 00:42:23Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#if !SWIG

#define DETECTOR_STR_BUFFER_SIZE 1024

#define DETECTOR_ERROR(s)   return (s)
#define DETECTOR_OK()       return "ok"

#define DETECTOR_SHOULD_NOT_BE_CALLED() \
  do { \
    fprintf(stderr, "ERROR: %s:%lu: raw detector function \"%s\" should not have been called.\n", \
      __FILE__, (unsigned long) __LINE__, __FUNCTION__); \
    abort(); \
  } while(0)

#define DETECTOR_CHECK_OPEN() \
  do { \
    if (!detectorrawgetisopen()) \
      DETECTOR_ERROR("no detector is currently open."); \
  } while (0)

#endif

// These functions must be implemented for each type of detector, either in C++ or Tcl.

extern const char *detectorrawstart(void);
extern const char *detectorrawopen(char *);
extern const char *detectorrawclose(void);

extern const char *detectorrawreset(void);

extern const char *detectorrawupdatestatus(void);
extern const char *detectorrawgetvalue(const char *);

extern const char *detectorrawsetcooler(const char *);
extern const char *detectorrawsetreadmode(const char *);
extern const char *detectorrawsetwindow(unsigned long, unsigned long, unsigned long, unsigned long);
extern const char *detectorrawsetbinning(unsigned long);

extern const char *detectorrawexpose(double, const char *);
extern const char *detectorrawcancel(void);
extern bool        detectorrawgetreadytoberead(void);
extern const char *detectorrawread(void);

extern const char *detectorrawfilterwheelmove(unsigned long);
extern const char *detectorrawfilterwheelupdatestatus(void);
extern const char *detectorrawfilterwheelgetvalue(const char *);

// These C++ functions are shared by all detectors.

extern const char *detectorrawgetdatavalue(const char *);

extern const char *detectorrawsetisopen(bool);
extern bool        detectorrawgetisopen(void);

extern const char *detectorrawsetsoftwaregain(unsigned long);
extern const char *detectorrawsetpixnx(unsigned long);
extern const char *detectorrawsetpixny(unsigned long);
extern const char *detectorrawsetpixnz(unsigned long);
extern unsigned long detectorrawgetpixnx(void);
extern unsigned long detectorrawgetpixny(void);
extern unsigned long detectorrawgetpixnz(void);

extern const char *detectorrawsetpixdatawindow(unsigned long, unsigned long, unsigned long, unsigned long);

extern const char *detectorrawpixstart(void);
extern const char *detectorrawpixnext(const long *, unsigned long);
extern const char *detectorrawpixnexthex(const char *);
extern const char *detectorrawpixend(void);

extern const char *detectorrawappendfitsdata(const char *, const char *, const char *, const char *, int, double, double);
