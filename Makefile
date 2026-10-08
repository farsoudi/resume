# Resume build system.
#
# Two optional local overlays (both gitignored) customise the build:
#   private.tex   -> first optional field
#   private-g.tex -> second optional field
# When an overlay is missing its slot renders empty, so the tracked source and
# resume-latest-web.pdf never contain either value.

TECTONIC     ?= tectonic
PUBLIC_PDF   := resume-latest-web.pdf
PHONE_PDF    := resume-phone.pdf
PUBLIC_G_PDF := resume-latest-web-g.pdf
PHONE_G_PDF  := resume-phone-g.pdf

.PHONY: all public phone public-g phone-g clean

all: public phone public-g phone-g

public:
	@set -e; restore=""; \
	for f in private.tex private-g.tex; do \
		if [ -f $$f ]; then mv -f $$f $$f.bak; restore="$$restore $$f"; fi; \
	done; \
	trap 'for f in $$restore; do mv -f $$f.bak $$f; done' EXIT; \
	$(TECTONIC) resume.tex; \
	mv -f resume.pdf $(PUBLIC_PDF)

phone:
	@set -e; restore=""; \
	for f in private-g.tex; do \
		if [ -f $$f ]; then mv -f $$f $$f.bak; restore="$$restore $$f"; fi; \
	done; \
	trap 'for f in $$restore; do mv -f $$f.bak $$f; done' EXIT; \
	$(TECTONIC) resume.tex; \
	mv -f resume.pdf $(PHONE_PDF)

public-g:
	@set -e; restore=""; \
	for f in private.tex; do \
		if [ -f $$f ]; then mv -f $$f $$f.bak; restore="$$restore $$f"; fi; \
	done; \
	trap 'for f in $$restore; do mv -f $$f.bak $$f; done' EXIT; \
	$(TECTONIC) resume.tex; \
	mv -f resume.pdf $(PUBLIC_G_PDF)

phone-g:
	@set -e; \
	$(TECTONIC) resume.tex; \
	mv -f resume.pdf $(PHONE_G_PDF)

clean:
	rm -f resume.pdf $(PHONE_PDF) $(PUBLIC_G_PDF) $(PHONE_G_PDF)
