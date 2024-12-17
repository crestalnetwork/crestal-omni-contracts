.PHONY: abi deploy upgrade upgrade-test check

ifdef ENV_FILE
include $(ENV_FILE)
endif

RPC_URL ?= http://127.0.0.1:8545

abi:
	cp out/BlueprintV1.sol/BlueprintV1.json artifacts/

deploy:
	forge script ./script/Deploy.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

upgrade:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/Upgrade.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

upgrade-test:
	forge script ./script/UpgradeTest.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

check:
	cast call --rpc-url $(RPC_URL) $(PROXY_ADDRESS) "VERSION()(string)"
