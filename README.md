# crestal-omni-contracts
Crestal Omnichain Smart Contracts

## Requirements

### Dependencies

Install [Foundry](https://book.getfoundry.sh/getting-started/installation).

Update Foundry to latest version:
```
foundryup
```
> Add `~/.foundry/bin` to `$PATH` if command is not found.

Install OpenZeppelin contracts:
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

(Optional) Recommend installing [solc-select](https://github.com/crytic/solc-select) to manage Solidity compiler versions.

Install Solidity prettier [as a tool](https://github.com/prettier-solidity/prettier-plugin-solidity) or [as a plugin in your favorite editor](https://prettier.io/docs/en/editors).

### Usage

Format source files:
```
make fmt
```

Build contracts:
```
forge build
```

Test contracts:
```
forge test
```
