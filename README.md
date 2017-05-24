# Sikoba Token Continuous

## Introductory notes

* one presale SKO is now represnted as 1,000 SKO1 (instead of SKOK as initially written on the web site)
* some initial (manual) testing completed, full testing remains to be done
* we aim to deploy the contract before 1st June, but reserve the right to delay by a few days if any issues are found during testing

## Functionality

* Mint function
  * for participants who provide funding in fiat and ETH prior to token sale start
  * as reward for help with the project
* Flag to indicate when minting completed
* Start contribution period - Thursday, 01-Jun-17 00:00:00 UTC = 1496275200
* End contribution period - Thursday, 31-Oct-17 23:59:59 UTC = 1509494399
* Tokens per ETH
  * 1 ETH = 1,650 SKO1 on 01-Jun-2017
  * 1 ETH = 1,200 SKO1 on 31-Oct-2107
  * linear decline of number of tokens per ETH over time
  * correponds to a continuous and (slightly) accelerating token price increase over time 
* Max funding in USD
  * `setUsdPerHundredETH(...)` to be called manually when rate deviates by more than 5%
  * Keep track of total funding * USD rate (it will be approximate, but we think that's ok)
  * Soft limit maximum finding in USD terms = 400,000
  * When soft limit reached accept contributions for an additional 24 hours (but not beyond the end of the contribution period)
* Pausing funding
  * The owner can temporarily stop funding via `pause()` in case there is some event or announcement which will materially affect the project.
  * Funding can be restarted via `restart()`

## Open issues

* need to decide if `totalUsdFunding` should include private sale
* need to decide on the size of the bonus pool

## To do just before launch  
  
* set the value of `usdPerHundredETH`
* initialise `totalUsdFunding` (if necessary)

## To do just after launch

* mint tokens for private sale participants
* mint tokens promised as reward for help during presale
* mint tokens for the bonus pool