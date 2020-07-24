UNAME	= $(shell uname -s)
ifeq ($(findstring BSD, $(UNAME)), BSD)
  UNAME	= BSD
endif

VPATH	= unix
ifeq ($(UNAME), Linux)
  VPATH	+= unix/linux
endif
ifeq ($(UNAME), BSD)
  VPATH	+= unix/bsd
endif

DIR	= $(shell pwd)
CC	= gcc
INC	= $(DIR) $(DIR)/unix
CFLAGS	= -Wall -O2 -g $(patsubst %, -I%, $(INC)) -fPIC

AR	= ar
ARFLAGS	= -rus

SYS	= libfli-sys.o
DEBUG	= libfli-debug.o
MEM	= libfli-mem.o
USB_IO	= libfli-usb.o libfli-usb-sys.o
ifeq ($(UNAME), Linux)
  PPORT_IO	= libfli-parport.o
endif
SERIAL_IO	= libfli-serial.o
IO	= $(USB_IO) $(PPORT_IO) $(SERIAL_IO)
CAM	= libfli-camera.o libfli-camera-parport.o libfli-camera-usb.o
FILT	= libfli-filter-focuser.o

ALLOBJ	= $(SYS) $(DEBUG) $(MEM) $(IO) $(CAM) $(FILT)

libfli.a: libfli.o $(ALLOBJ)
	$(AR) $(ARFLAGS) $@ $^

.PHONY: clean
clean:
	rm -f $(ALLOBJ) libfli.o libfli.a
