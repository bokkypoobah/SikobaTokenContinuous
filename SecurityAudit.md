# SikobaTokenContinuous Audit (Work In Progress)

See [README.md](README.md).

<br />

<hr />

**Table of contents**
* [Background And History](#background-and-history)
* [Notes](#notes)
* [Security Overview Of The Smart Contract](#security-overview-of-the-smart-contract)
  * [Risks](#risks)
* * [Other Notes](#other-notes)
  [Comments On The Source Code](#comments-on-the-source-code)
* [References](#references)

<br />

<hr />

## Background And History

* May 17 2017 BPB Provided skeleton for token contract with crowdfund minting
* May 25 2017 AK Completed crowdfund minting ranges and calculations
* May 29 2017 BPB Completed testing and security audit

<br />

<hr />

## Notes

* The SikobaContinuousSale contract implements the ERC20 token standard
* The owner is able to mint tokens for funding received outside this contract
* Users can send ethers (ETH) to this contract and receive SKO1 tokens immediately back to their sending accounts
* The number of SKO1 tokens per ETH contributed is linearly interpolated between a rate at the start and a rate at the end
* ETH sent to the contract is immediately transferred into the owner's account
* ETH contributions can be made between the START_DATE and END_DATE
* If the total ETH contributions exceeds a maximum, the a softEndDate is set to 24 hours after the maximum threshold is breached
* Tokens are immediately transferable once a user has bought the tokens

<br />

<hr />

## Security Overview Of The Smart Contract
* [x] The smart contract has been kept relatively simple
* [x] The code has been tested for the normal [ERC20](https://github.com/ethereum/EIPs/issues/20) use cases, and around some of the boundary cases
  * [x] Deployment, with correct `symbol()`, `name()`, `decimals()` and `totalSupply()`
  * [x] Block for ethers being sent to this contract outside the crowdfunding dates
  * [x] `transfer(...)` from one account to another
  * [x] `approve(...)` and `transferFrom(...)` from one account to another
  * [x] `transferOwnership(...)` and `acceptOwnership()` of the token contract
* [x] The testing has been done using geth v1.6.1-stable-021c3c28/darwin-amd64/go1.8.1 and solc 0.4.11+commit.68ef5810.Darwin.appleclang instead of one of the testing frameworks and JavaScript VMs to simulate the live environment as closely as possible
* [x] The `approveAndCall(...)` function has been omitted from this token smart contract as the side effects of this function has not been evaluated fully
* [x] There is no logic with potential division by zero errors
* [x] All numbers used are uint256 (with the exception of `decimals`), reducing the risk of errors from type conversions
* [x] Areas with potential overflow errors in `transfer(...)` and `transferFrom(...)` have the logic to prevent overflows
* [x] Areas with potential underflow errors in `transfer(...)` and `transferFrom(...)` have the logic to prevent underflows
* [x] There is a potential underflow error in `unitsPerEthAt(...)` but this is protected by a conditional check
* [x] Function and event names are differentiated by case - function names begin with a lowercase character and event names begin with an uppercase character
* [x] The default constructor will receive contributions during the crowdfunding phase and mint tokens
* [x] The function `transferAnyERC20Token(...)` has been added in case the owner has to free any accidentally trapped ERC20 tokens
* [x] The test results can be found in [test/test1results.txt](test/test1results.txt) for the results and [test/test1output.txt](test/test1output.txt) for the full output
* [x] ETH contributed to this smart contract is immediately moved to the owner's account
* [x] A crowdfunding pause / restart is available to pause and then restart the contract being able to receive contributions
* [x] The `send(...)` call is the last statements in the control flow to prevent the hijacking of the control flow
* [x] The return status from `send(...)` calls are all checked and invalid results will **throw**

<br />

### Risks

* This token contract will not hold any ethers
* In the case where a security vulnerability in this contract is discovered or exploited, a new token contract can be deployed to a new address with the correct(ed) balances transferred over from the old contract to the new contract
* This token contract suffers from the same ERC20 double spend issue with the `approve(...)` and `transferFrom(...)` workflow, but this is a low risk exploit where:
  * Account1 approves for account2 to spend `x`
  * Account1 changes the approval limit to `y`. Account2 waits for the second approval transaction to be broadcasted and sends a `transferFrom(...)` to spend up to `x` before the second approval is mined
  * Account2 spends up to `y` after the second approval is mined. Account2 can therefore spend up to `x` + `y`, instead of `x` or `y`
  * To avoid this double spend, account1 has to set the approval limit to `0`, checking the `allowance(...)` and then setting the approval limit to `y` if account2 has not spent `x`

<br />

<hr />

### Other Notes

* This token contract has been developed and tested by Alex Kampa / Sikoba and Bok Consulting Pty Ltd
* While the SikobaContinuousSale Solidity code logic has been audited, there are small possibilities of errors that could compromise the security of this contract. This includes errors in the Solidity to bytecode compilation, errors in the execution of the VM code, or security failures in the Ethereum blockchain
  * For example see [Security Alert – Solidity – Variables can be overwritten in storage](https://blog.ethereum.org/2016/11/01/security-alert-solidity-variables-can-overwritten-storage/)
* Some of the code changes, the testing and the security audit were conducted by Bok Consulting, and this is a potential conflict of interest

<br />

<hr />

## Comments On The Source Code

My comments in the following code are market in the lines beginning with `// NOTE: `.

Following is the source code for [blob/08a9a73b46fd28e70c143e692244f2c2349cc263/contracts/SikobaContinuousSale.sol](blob/08a9a73b46fd28e70c143e692244f2c2349cc263/contracts/SikobaContinuousSale.sol): 

```javascript
pragma solidity ^0.4.8;

// ----------------------------------------------------------------------------
//
// Important information
//
// For details about the Sikoba continuous token sale, and in particular to find 
// out about risks and limitations, please visit:
//
// http://www.sikoba.com/www/presale/index.html
//
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
//
// Owned contract
//
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;
    event OwnershipTransferred(address indexed _from, address indexed _to);

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    function transferOwnership(address _newOwner) onlyOwner {
        newOwner = _newOwner;
    }

    // NOTE: The conditional check should throw if the check fails
    function acceptOwnership() {
        if (msg.sender == newOwner) {
            OwnershipTransferred(owner, newOwner);
            owner = newOwner;
        }
    }
}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/issues/20
//
// ----------------------------------------------------------------------------
// NOTE: Ok
contract ERC20Interface {
    function totalSupply() constant returns (uint256 totalSupply);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) 
        returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant 
        returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, 
        uint256 _value);
}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20
//
// ----------------------------------------------------------------------------
contract ERC20Token is Owned, ERC20Interface {
    // NOTE: Ok
    uint256 _totalSupply = 0;

    // ------------------------------------------------------------------------
    // Balances for each account
    // ------------------------------------------------------------------------
    // NOTE: Ok
    mapping(address => uint256) balances;

    // ------------------------------------------------------------------------
    // Owner of account approves the transfer of an amount to another account
    // ------------------------------------------------------------------------
    // NOTE: Ok
    mapping(address => mapping (address => uint256)) allowed;

    // ------------------------------------------------------------------------
    // Get the total token supply
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function totalSupply() constant returns (uint256 totalSupply) {
        totalSupply = _totalSupply;
    }

    // ------------------------------------------------------------------------
    // Get the account balance of another account with address _owner
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from owner's account to another account
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function transfer(
        address _to,
        uint256 _amount
    ) returns (bool success) {
        if (balances[msg.sender] >= _amount             // User has balance
            && _amount > 0                              // Non-zero transfer
            && balances[_to] + _amount > balances[_to]  // Overflow check
        ) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(msg.sender, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    // ------------------------------------------------------------------------
    // Allow _spender to withdraw from your account, multiple times, up to the
    // _value amount. If this function is called again it overwrites the
    // current allowance with _value.
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function approve(
        address _spender,
        uint256 _amount
    ) returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    // ------------------------------------------------------------------------
    // Spender of tokens transfer an amount of tokens from the token owner's
    // balance to another account. The owner of the tokens must already
    // have approve(...)-d this transfer
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) returns (bool success) {
        if (balances[_from] >= _amount                  // From a/c has balance
            && allowed[_from][msg.sender] >= _amount    // Transfer approved
            && _amount > 0                              // Non-zero transfer
            && balances[_to] + _amount > balances[_to]  // Overflow check
        ) {
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function allowance(
        address _owner, 
        address _spender
    ) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}


// ----------------------------------------------------------------------------
//
// Accept funds and mint tokens
//
// ----------------------------------------------------------------------------
contract SikobaContinuousSale is ERC20Token {

    // ------------------------------------------------------------------------
    // Token information
    // ------------------------------------------------------------------------
    // NOTE: Ok
    string public constant symbol = "SKO1";
    string public constant name = "Sikoba Continuous Sale";
    uint8 public constant decimals = 18;

    // Thursday, 01-Jun-17 00:00:00 UTC
    // NOTE: Ok. 1496275200 => Thursday, 01-Jun-17 00:00:00 UTC from http://www.unixtimestamp.com
    uint256 public constant START_DATE = 1496275200;

    // Tuesday, 31-Oct-17 23:59:59 UTC
    // NOTE: Ok. 1509494399 => Tuesday, 31-Oct-17 23:59:59 UTC from http://www.unixtimestamp.com
    uint256 public constant END_DATE = 1509494399;

    // Number of SKO1 units per ETH at beginning and end
    // NOTE: Ok. Make sure that the units is linearly decreasing or an underflow may occur
    uint256 public constant START_SKO1_UNITS = 1650;
    uint256 public constant END_SKO1_UNITS = 1200;

    // Minimum contribution amount is 0.01 ETH
    // NOTE: Ok. 0.01 ETH
    uint256 public constant MIN_CONTRIBUTION = 10**16;

    // One day soft time limit if max contribution reached
    // NOTE: Ok
    uint256 public constant ONE_DAY = 24*60*60;

    // Max funding and soft end date
    // NOTE: Ok
    uint256 public constant MAX_USD_FUNDING = 400000;
    uint256 public totalUsdFunding;
    bool public maxUsdFundingReached = false;
    uint256 public usdPerHundredEth;
    uint256 public softEndDate = END_DATE;

    // Ethers contributed and withdrawn
    // NOTE: Ok
    uint256 public ethersContributed = 0;

    // Status variables
    // NOTE: Ok
    bool public mintingCompleted = false;
    bool public fundingPaused = false;

    // Multiplication factor for extra integer multiplication precision
    // NOTE: Ok. Could make it 10**18 if desired
    uint256 public constant MULT_FACTOR = 10**9;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    // NOTE: Ok
    event UsdRateSet(uint256 _usdPerHundredEth);
    event TokensBought(address indexed buyer, uint256 ethers, uint256 tokens, 
          uint256 newTotalSupply, uint256 unitsPerEth);

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    // NOTE: Ok. Only the owner will deploy this contract
    function SikobaContinuousSale(uint256 _usdPerHundredEth) {
        setUsdPerHundredEth(_usdPerHundredEth);
    }

    // ------------------------------------------------------------------------
    // Owner sets the USD rate per 100 ETH - used to determine the funding cap
    // If coinmarketcap $131.14 then set 13114
    // ------------------------------------------------------------------------
    // NOTE: Ok. Only the owner can execute this function
    function setUsdPerHundredEth(uint256 _usdPerHundredEth) onlyOwner {
        usdPerHundredEth = _usdPerHundredEth;
        UsdRateSet(_usdPerHundredEth);
    }

    // ------------------------------------------------------------------------
    // Calculate the number of tokens per ETH contributed
    // Linear (START_DATE, START_SKO1_UNITS) -> (END_DATE, END_SKO1_UNITS)
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function unitsPerEth() constant returns (uint256) {
        return unitsPerEthAt(now);
    }

    // NOTE: Ok. Checked for division by 0, underflow and overflow
    function unitsPerEthAt(uint256 at) constant returns (uint256) {
        if (at < START_DATE) {
            return START_SKO1_UNITS * MULT_FACTOR;
        } else if (at > END_DATE) {
            return END_SKO1_UNITS * MULT_FACTOR;
        } else {
            return START_SKO1_UNITS * MULT_FACTOR
                - ((START_SKO1_UNITS - END_SKO1_UNITS) * MULT_FACTOR 
                   * (at - START_DATE)) / (END_DATE - START_DATE);
        }
    }

    // ------------------------------------------------------------------------
    // Buy tokens from the contract
    // ------------------------------------------------------------------------
    // NOTE: Ok
    function () payable {
        buyTokens();
    }

    // NOTE: Ok. This function can also be called directly. The input number range is
    //       limited by the number of ETH sent
    function buyTokens() payable {
        // Check conditions
        // NOTE: Ok
        if (fundingPaused) throw;
        if (now < START_DATE) throw;
        if (now > END_DATE) throw;
        if (now > softEndDate) throw;
        if (msg.value < MIN_CONTRIBUTION) throw;

        // Issue tokens
        // NOTE: Ok
        uint256 _unitsPerEth = unitsPerEth();
        uint256 tokens = msg.value * _unitsPerEth / MULT_FACTOR;
        _totalSupply += tokens;
        balances[msg.sender] += tokens;
        Transfer(0x0, msg.sender, tokens);

        // Approximative funding in USD
        // NOTE: Ok
        totalUsdFunding += msg.value * usdPerHundredEth / 10**20;
        if (!maxUsdFundingReached && totalUsdFunding > MAX_USD_FUNDING) {
            softEndDate = now + ONE_DAY;
            maxUsdFundingReached = true;
        }

        // NOTE: Ok
        ethersContributed += msg.value;
        TokensBought(msg.sender, msg.value, tokens, _totalSupply, _unitsPerEth);

        // Send balance to owner
        // NOTE: Ok. Last statement in control flow, and return status will throw if there is an error
        if (!owner.send(this.balance)) throw;
    }

    // ------------------------------------------------------------------------
    // Pause and restart funding
    // ------------------------------------------------------------------------
    // NOTE: Ok. Only owner
    function pause() external onlyOwner {
        fundingPaused = true;
    }

    // NOTE: Ok. Only owner
    function restart() external onlyOwner {
        fundingPaused = false;
    }


    // ------------------------------------------------------------------------
    // Owner can mint tokens for contributions made outside the ETH contributed
    // to this token contract. This can only occur until mintingCompleted is
    // true
    // ------------------------------------------------------------------------
    // NOTE: Ok. Only owner
    function mint(address participant, uint256 tokens) onlyOwner {
        if (mintingCompleted) throw;
        balances[participant] += tokens;
        _totalSupply += tokens;
        Transfer(0x0, participant, tokens);
    }

    // NOTE: Ok. Only owner
    function setMintingCompleted() onlyOwner {
        mintingCompleted = true;
    }

    // ------------------------------------------------------------------------
    // Transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    // NOTE: Ok. Only owner
    function transferAnyERC20Token(
        address tokenAddress, 
        uint256 amount
    ) onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, amount);
    }
}
```

<br />

<hr />

## References

* [Ethereum Contract Security Techniques and Tips](https://github.com/ConsenSys/smart-contract-best-practices)
* Solidity [bugs.json](https://github.com/ethereum/solidity/blob/develop/docs/bugs.json) and [bugs_by_version.json](https://github.com/ethereum/solidity/blob/develop/docs/bugs_by_version.json).

<br />

(c) BokkyPooBah / Bok Consulting Pty Ltd for Sikoba - May 29 2017