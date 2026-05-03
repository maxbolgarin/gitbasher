VERSION := $(shell git describe --tags --always 2>/dev/null | sed 's/^v//' || echo "dev")

.PHONY: build
build:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb "$(VERSION)"
	@chmod +x ./dist/gitb

.PHONY: install
install: build
	@cp ./dist/gitb ~/.local/bin/gitb
	@chmod +x ~/.local/bin/gitb

.PHONY: install-completions
install-completions:
	@./completion/install.sh

.PHONY: uninstall-completions
uninstall-completions:
	@./completion/install.sh --uninstall

.PHONY: release
release: build
	@echo "Build complete. Use CI workflow to create releases."
	@echo "The dist/gitb file is built locally but not committed to the repo."

.PHONY: test
test:
	@cd tests && ./run_tests.sh

.PHONY: test-file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test_sanitization.bats"; \
		exit 1; \
	fi
	@cd tests && ./run_tests.sh $(FILE)