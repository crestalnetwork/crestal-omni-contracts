.PHONY: fmt abi deploy check

RPC_URL ?= http://127.0.0.1:8545

fmt:
	npx prettier --write --plugin=prettier-plugin-solidity 'src/**/*.sol'

abi:
	cp out/Blueprint.sol/Blueprint.json artifacts/

deploy:
	forge create --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) src/Blueprint.sol:Blueprint

check:
	cast call --rpc-url $(RPC_URL) $(CONTRACT_ADDRESS) "VERSION()(string)"
