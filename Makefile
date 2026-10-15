.PHONY: help test package package-check icon docs docs-install docs-dev docs-build docs-preview docs-clean

# The script itself needs no build step -- REAPER runs the .lua files where they sit. This file is
# for the parts that do have a toolchain: the test suite, the release zip, the icon, and the docs site.

# Defined up here because the icon target needs it too, and Make expands a prerequisite the moment
# it reads the rule -- a definition further down would expand to nothing.
DOCS_DIR := docs
# Matches `base` in docs/astro.config.mjs; astro preview serves the site under it.
DOCS_URL := http://localhost:4321/Reaper-ListOfInstrumentsAndEffects/

help:
	@echo "Docs (Astro + Starlight, in docs/):"
	@echo "  make docs               read them locally -- build, then serve at $(DOCS_URL)"
	@echo "  make docs-dev           live-reload dev server, for writing"
	@echo "  make docs-build         static build into docs/dist/"
	@echo "  make docs-clean         remove docs/dist and docs/.astro"
	@echo ""
	@echo "Icon:"
	@echo "  make icon               re-render every icon output from icon/icon.svg"
	@echo ""
	@echo "Tests (need a standalone Lua: brew install lua):"
	@echo "  make test               run the suite outside REAPER"
	@echo ""
	@echo "Release:"
	@echo "  make package-check      validate the files the manifest provides"
	@echo "  make package            that, then zip them into dist/ for a manual install"

test:
	./tests/run.sh

# The zip the Release workflow attaches to a GitHub release. The file list is the manifest's
# @provides block, so the zip holds exactly what ReaPack installs.
package-check:
	@python3 .github/scripts/package.py --check

package:
	@python3 .github/scripts/package.py dist

# Re-render the favicons, the README mark and the REAPER toolbar strips from the one master SVG.
# Deliberately NOT a prerequisite of docs-build: the outputs are committed and the master changes
# about never, so paying for it on every docs build would be waste.
icon: node_modules
	npm run --silent icon

node_modules:
	npm install

# ---- Docs (Astro + Starlight): read them offline, or let CI publish to GitHub Pages ----

# Install docs dependencies only when they're missing (Node + npm required).
$(DOCS_DIR)/node_modules:
	cd $(DOCS_DIR) && npm install

# Explicit one-time install target.
docs-install: $(DOCS_DIR)/node_modules

# The one to reach for: build the site and serve it, exactly as published.
docs: docs-preview

# Live-reload dev server, for writing.
docs-dev: $(DOCS_DIR)/node_modules
	cd $(DOCS_DIR) && npm run dev

# Static build into docs/dist/
docs-build: $(DOCS_DIR)/node_modules
	cd $(DOCS_DIR) && npm run build

# Serve the built site locally (builds first if needed).
docs-preview: docs-build
	@echo "Serving the docs at $(DOCS_URL) -- Ctrl-C to stop"
	cd $(DOCS_DIR) && npm run preview

docs-clean:
	rm -rf $(DOCS_DIR)/dist $(DOCS_DIR)/.astro
