.PHONY: build
build:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb
	@chmod +x ./dist/gitb

.PHONY: install
install: build
	@cp ./dist/gitb /usr/local/bin/gitb
	@chmod +x /usr/local/bin/gitb

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