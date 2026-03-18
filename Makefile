.PHONY: install test lint clean

install:
	@bash install.sh

test:
	@bash tests/run_tests.sh

lint:
	@shellcheck scripts/*.sh tests/*.sh

clean:
	@rm -rf ~/.config/alpaca-skill/
