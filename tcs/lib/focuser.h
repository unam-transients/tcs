////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#define FOCUSER_STR_BUFFER_SIZE 1024

#define FOCUSER_ERROR(s)  return (s)
#define FOCUSER_OK()      return "ok"

extern bool focuseropened;

#define FOCUSER_CHECK_OPENED() \
  do { \
    if (!focuseropened) \
      FOCUSER_ERROR("no focuser is currently opened."); \
  } while (0)

#endif

extern const char *focuserrawopen(char *);
extern const char *focuserrawclose(void);
extern const char *focuserrawmove(long);

#if !SWIG
extern const char *focuserdescription;
extern long        focuserposition;
extern long        focuserminposition;
extern long        focusermaxposition;
#endif

extern const char *focuserrawgetdescription(void);

extern const char *focuserrawupdateposition(void);
extern long        focuserrawgetposition(void);
extern long        focuserrawgetminposition(void);
extern long        focuserrawgetmaxposition(void);
