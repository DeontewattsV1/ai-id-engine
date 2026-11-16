# SPDX-License-Identifier: MIT
# Out-of-tree build of the id-engine driver core:  make -C fw
KDIR ?= /lib/modules/$(shell uname -r)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
