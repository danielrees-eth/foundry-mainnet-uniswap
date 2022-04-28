# Motivation

Designing an effective test suite for smart contracts is equal parts art and science. 

Unit tests will often not adequately show the behavior of interactions within the composable DeFi ecosystem. Each external contract interaction requires mock contracts, which must be designed and deployed. The assumptions made in the mock contracts might create a testing environment which is far removed from the mainnet environment. Furthermore, compiling and deploying these contracts increases the time to run the test suite, which reduces the likelyhood that they will be run frequently. 

In these cases, is useful to test with a mainnet fork. This repo demostrates a mainnet fork test using foundry to executes simple trades on Uniswap.

# Installation

From the project root, run:
```
sh install.sh
```

# Run Tests

From the project root, run:
```
forge test --fork-url https://mainnet.infura.io/v3/d11feab0709c4aec9bcad8f3e1a49c08 --etherscan-api-key IF59W4SY95W3E6D9XX62R1HVNFBBC5FRQ1 -vvvv
```

