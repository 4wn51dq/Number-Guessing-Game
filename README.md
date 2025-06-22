# Number Guessing Gambling Game 
##### using solidity 

### Game.sol => Game Rules:
#### overview: 
- each game round will have a range as 10^roundNumber 
- a player has to guess a number within this range 
- difficulty increases in each round as the range to guess from increases
- winner would be the participant(s) who guess(es) the correct or closest value.

#### randomness:
- using chainlink-evm VRF to generate random number within the range 
- doing this will cost some eth due to gas cost of execution of vrf
- only the coupier would know this random number 

#### pool: 
- the pool money will increase with subsequently increasing difficulty
- there has to be a fixed window time open for each round for pooling money and proposing guess
- a player has to deposit a participating fee first and then can pool eth for any round they want to 
- the pooled money will be stored in the contract
- it also has to be ensured that all the pooled money for each round minus the gas cost for ensuring randomness will be given to the winner or distributed equally among winners 







## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
