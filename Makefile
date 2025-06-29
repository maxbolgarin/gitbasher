.PHONY: build
build:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb
	@chmod +x ./dist/gitb

.PHONY: build-commit
build-commit: build
	@git add ./dist/gitb
	@git commit -m "chore: build new script"

.PHONY: install
install:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb
	@cp ./dist/gitb /usr/local/bin/gitb
	@chmod +x /usr/local/bin/gitb
	@git add ./dist/gitb
	@git commit -m "chore: build new script"