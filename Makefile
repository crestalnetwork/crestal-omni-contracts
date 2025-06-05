.PHONY: abi deploy upgrade whitelist fee-wallet update-worker update-payment verify-impl verify-proxy check slither mythril

ifdef ENV_FILE
include $(ENV_FILE)
endif

LATEST ?= V6
RPC_URL ?= http://127.0.0.1:8545
UPGRADE_TO ?= $(LATEST)

abi:
	cp out/Blueprint$(LATEST).sol/Blueprint$(LATEST).json artifacts/

deploy:
	forge script ./script/Deploy.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

upgrade:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/Upgrade$(UPGRADE_TO).s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

whitelist:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/UpdateWhitelist.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

fee-wallet:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/SetFeeCollectionWallet.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

update-worker:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/UpdateWorker.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

update-payment:
	PROXY_ADDRESS=$(PROXY_ADDRESS) forge script ./script/UpdatePayment.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

verify-impl:
	FOUNDRY_PROFILE=verify ETHERSCAN_API_KEY=$(ETHERSCAN_API_KEY) forge verify-contract --verifier-url $(VERIFIER_URL) --watch $(IMPL_ADDRESS) src/Blueprint$(LATEST).sol:Blueprint$(LATEST)

verify-proxy:
	FOUNDRY_PROFILE=verify ETHERSCAN_API_KEY=$(ETHERSCAN_API_KEY) forge verify-contract --verifier-url $(VERIFIER_URL) --watch $(PROXY_ADDRESS) lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --constructor-args `cast abi-encode "constructor(address,bytes)" $(PROXY_DEPLOY_ARG1) $(PROXY_DEPLOY_ARG2)`

check:
	cast call --rpc-url $(RPC_URL) $(PROXY_ADDRESS) "VERSION()(string)"

slither:
	slither ./src/Blueprint$(LATEST).sol --checklist --filter-paths "openzeppelin"

mythril:
	myth analyze ./src/Blueprint$(LATEST).sol --solc-json solc_remappings.json
