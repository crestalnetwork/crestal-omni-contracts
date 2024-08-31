# crestal-omni-contracts
Crestal Omnichain Smart Contracts

## Requirements

### Dependencies

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

Update Foundry to latest version:
```bash
foundryup
```
> Add `~/.foundry/bin` to `$PATH` if command is not found.

Install OpenZeppelin contracts:
```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-foundry-upgrades
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

### Tools

(Optional) Recommend installing [solc-select](https://github.com/crytic/solc-select) to manage Solidity compiler versions.

## Usage

### Development

Format source files:
```bash
forge fmt
```

Build contracts:
```bash
forge build
```

Test contracts:
```bash
forge test
```

Generate abi (for external access):
```bash
make abi
```

### Deployment

Local deployment setup (start local node in a separate window):
```bash
anvil
```

Deploy (locally - copy private key from anvil output):
```bash
PRIVATE_KEY=xxx make deploy
```

Sanity check (locally):
```bash
CONTRACT_ADDRESS=xxx make check
```

Deploy (to networks):
```bash
PRIVATE_KEY=xxx RPC_URL=https://xxx make deploy
```

Sanity check (on networks):
```bash
CONTRACT_ADDRESS=xxx RPC_URL=https://xxx make check
```
