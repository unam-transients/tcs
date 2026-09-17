obj-m		:= fliusb.o

KDIR 		?= /lib/modules/$(shell uname -r)/build

EXTRA_CFLAGS		+= -O2 -Wall

# Enable only when needed:
#EXTRA_CFLAGS         += -DDEBUG      # enable debug messages
#EXTRA_CFLAGS         += -DASYNCWRITE # enable asynchronous writes
#EXTRA_CFLAGS         += -DSGREAD     # enable scatter-gather reads

.PHONY: all modules clean install

all: modules

modules:
	$(MAKE) -C $(KDIR) M=$(shell pwd) modules

clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd) clean

install: modules
	$(MAKE) -C $(KDIR) M=$(shell pwd) modules_install
