.PHONY: fmt abi

fmt:
	npx prettier --write --plugin=prettier-plugin-solidity 'src/**/*.sol'

abi:
	cp out/Blueprint.sol/Blueprint.json artifacts/
