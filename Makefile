.PHONY: abi deploy check

RPC_URL ?= http://127.0.0.1:8545

abi:
	cp out/BlueprintV1.sol/BlueprintV1.json artifacts/

deploy:
	forge script ./script/Deploy.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

check:
	cast call --rpc-url $(RPC_URL) $(CONTRACT_ADDRESS) "VERSION()(string)"
