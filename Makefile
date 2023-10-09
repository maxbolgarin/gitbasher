.PHONY: build
build:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb

.PHONY: install
install:
	@./dist/build.sh ./scripts/gitb.sh ./dist/gitb
	@sudo mv ./dist/gitb /usr/local/bin/gitb
	@sudo chmod +x /usr/local/bin/gitb
