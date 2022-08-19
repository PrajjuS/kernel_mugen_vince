NAME ?= Mugen
DATE := $(shell date "+%d%m%Y-%I%M")
CODE := Saisho
VERSION := 4.9-$(LINUX_VERSION)

SZIP := $(NAME)-$(CODE)-$(VERSION)-STABLE-$(DATE).zip
BZIP := $(NAME)-$(CODE)-$(VERSION)-BETA-$(DATE).zip


EXCLUDE := Makefile *.git* *.jar* Mugen* *placeholder*

stable: $(SZIP)
beta: $(BZIP)

$(SZIP):
	@echo "Creating ZIP: $(SZIP)"
	@zip -r9 "$@" . -x $(EXCLUDE)
	@echo "Done."

$(BZIP):
	@echo "Creating ZIP: $(BZIP)"
	@zip -r9 "$@" . -x $(EXCLUDE)
	@echo "Done."

clean:
	@rm -vf *.zip*
	@rm -vf zImage
	@echo "Done."
