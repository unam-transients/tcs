////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

extern "C" {

// tcs_start: 
//
// This function must be called once before any other functions are called.

void tcs_start(void);

// tcs_roboticoperationallowed: 

// This function determines whether robotic operations are allowed. If
// not, the only library functions that should be called are tcs_start,
// tcs_roboticoperationallowed, tcs_getcomponents, tcs_getkeys, and
// tcs_getvalue. If the robotic operations are allowed, the function
// returns 1. Otherwise, the function returns 0.

int tcs_roboticoperationallowed(void);

// tcs_getcomponentnames and tcs_getvaluenames: 

// These functions return NULL-terminated arrays of the NUL-terminate
// strings whose contents are components and keys. The arrays have the
// same size. The corresponding elements of the arrays form valid
// arguments to tcs_getvalue().

const char **tcs_getcomponents(void);
const char **tcs_getkeys(void);

// tcs_getvalue: 

// This function attempts to retrieve and return the TCS value associated
// with a component and key. The component and key arguments must be
// NUL-terminated strings. If the component and key arguments are valid
// and the value associated with them can be successfully obtained from
// the TCS, the function returns the value. Otherwise, the function
// returns NULL.
 
// The values are cached in the library and the cache updated only by
// tcs_start and by tcs_getvalue with a component argument of "tcs" and
// a key argument of "ready".

const char *tcs_getvalue(const char *component, const char *key);

// tcs_setvalue: 

// This function attempts to set the TCS value associated with a
// component and key. The component, key, and value arguments must be
// NUL-terminated strings. If the component and key arguments are valid,
// the function attempts to set the TCS value associated with them to
// the value argument. If the value is successfully set, the function
// returns 0. Otherwise, the function returns -1.

int tcs_setvalue(const char *component, const char *key, const char *value);

// tcs_move: 

// This function requests the TCS to move to a fixed HA and declination.
// The ha and delta arguments are in degrees. If the move is accepted by
// the TCS, the function returns 0. Otherwise, the function returns -1.

int tcs_move(double ha, double delta);

// tcs_track: 

// This function requests the TCS to track a target. The alpha, delta,
// alphaoffset, and deltaoffset arguments are in degrees. The equinox
// argument is in Julian years. The target is at offset on the sky by
// alphaoffset to the east and deltaoffset to the north from the
// specified right ascension and declination. If the request is accepted
// by the TCS, the function returns 0. Otherwise, the function returns
// -1.

int tcs_track(double alpha, double delta, double equinox, double alphaoffset, double deltaoffset);

// tcs_offset: 

// This function requests the TCS to track a target. The TCS must be
// already tracking. The alphaoffset and deltaoffset arguments are in
// degrees. The target is offset on the sky by alphaoffset to the
// east and deltaoffset to the north from the right ascension and
// declination specified by the latest tracking request. If the request
// is accepted by the TCS, the function returns 0. Otherwise, the
// function returns -1.

int tcs_offset(double alphaoffset, double deltaoffset);

// tcs_offset: 

// This function requests the TCS to guide. The TCS must be already
// tracking. The alphaoffset and deltaoffset arguments are in degrees.
// The mount is offset on the sky by alphaoffset to the east and
// deltaoffset to the north from the current position. If the request is
// accepted by the TCS, the function returns 0. Otherwise, the function
// returns -1.

int tcs_guide(double alphaoffset, double deltaoffset);

}
