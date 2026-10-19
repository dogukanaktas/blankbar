# Builds and installs the blankbar command. No sudo with the default PREFIX.
PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
BINARY := .build/release/blankbar

.PHONY: build test install uninstall clean

build:
	swift build -c release --disable-sandbox

test:
	swift test

install: build
	install -d "$(BINDIR)"
	@# Copy, then rename over the old file: overwriting a binary in place can make
	@# macOS kill the running copy (and the next launch) on a code signature mismatch.
	install -m 755 "$(BINARY)" "$(BINDIR)/.blankbar.new"
	mv -f "$(BINDIR)/.blankbar.new" "$(BINDIR)/blankbar"
	@echo "Installed $(BINDIR)/blankbar"
	@case ":$$PATH:" in *":$(BINDIR):"*) ;; *) \
		echo ""; \
		echo "$(BINDIR) is not in your PATH. Add it, for zsh:"; \
		echo "  echo 'export PATH=\"$(BINDIR):\$$PATH\"' >> ~/.zshrc && exec zsh"; \
		echo "or run blankbar as $(BINDIR)/blankbar";; \
	esac
	@echo ""
	@echo "Next: blankbar install"

uninstall:
	@# Run as yourself: blankbar refuses root. Removing the file goes on regardless.
	-@if [ -x "$(BINDIR)/blankbar" ] && [ "$$(id -u)" != 0 ]; then "$(BINDIR)/blankbar" uninstall; fi
	rm -f "$(BINDIR)/blankbar"

clean:
	rm -rf .build
