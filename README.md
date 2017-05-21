# Sikoba Token Continuous

## Requirements

* Mint function for participants who provide funding in fiat and ETH prior to token sale start
* Flag to indicate when minting completed
* Start contribution period - Thursday, 01-Jun-17 00:00:00 UTC = 1496275200
* End contribution period - Thursday, 31-Oct-17 23:59:59 UTC = 1509494399
* Tokens per ETH
  * 1 ETH = 1,650 SKO1 on 01-Jun-2017
  * 1 ETH = 1,200 SKO1 on 31-Oct-2107
  * linear decline of number of tokens per ETH over time
* Max funding in USD
  * `setUsdPerHundredETH(...)` to be called manually when rate deviates by more than 5%
  * Keep track of total funding * USD rate
  * Soft limit maximum finding in USD terms = 400,000
  * When soft limit reached accept contributions for an additional 24 hours
* Pausing funding
  * The owner can temporarily stop funding via `pause()` in case there is some event or announcement which will materially affect the project.
  * Funding can be restarted via `restart()`
* Multisig wallet to receive funds (???)
