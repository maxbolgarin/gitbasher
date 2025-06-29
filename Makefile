.PHONY: build
build:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb
	@chmod +x ./dist/gitb

.PHONY: install
install: build
	@cp ./dist/gitb /usr/local/bin/gitb
	@chmod +x /usr/local/bin/gitb

.PHONY: release
release: install
	@git add ./dist/gitb
	@git commit -m "chore: build new script"