# Sikoba Token Continuous

## Requirements

* Mint function for participants who provide funding in fiat and ETH prior to token sale start
* Flag to indicate when minting completed
* Start contribution period - Jun 01 2017
* End contribution period - Oct 29 2017 (150 days)
* Token price
  * 1 ETH = 1,650 SKO0 on Jun 01 2017
  * 1 ETH = 1,200 SKO0 on Oct 29 2017 (1,650 - 1200 = 450 = 3 * 150). Price down by 3 SKO0 per day, linearly (not stepped)
* Max funding in USD
  * `setUSDRate(...)` to be called manually when rate deviates by more than 5%
  * Keep track of total funding * USD rate and sale completed when this amount exceeds the max USD funding
* Multisig wallet to receive funds
