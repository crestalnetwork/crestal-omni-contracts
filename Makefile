.PHONY: fmt

fmt:
	npx prettier --write --plugin=prettier-plugin-solidity 'src/**/*.sol'
