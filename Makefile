.PHONY: fmt abi deploy deploy

RPC_URL ?= http://127.0.0.1:8545

fmt:
	npx prettier --write --plugin=prettier-plugin-solidity 'src/**/*.sol'

abi:
	cp out/Blueprint.sol/Blueprint.json artifacts/

deploy:
	forge create --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) src/Blueprint.sol:Blueprint
