# SikobaTokenContinuous Audit (Work In Progress)

(fill this in)

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

(fill this in)

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

<br />

<hr />

## Security Overview Of The Smart Contract
* [ ] The smart contract has been kept relatively simple
* [ ] The code has been tested for the normal [ERC20](https://github.com/ethereum/EIPs/issues/20) use cases, and around some of the boundary cases
  * [ ] Deployment, with correct `symbol()`, `name()`, `decimals()` and `totalSupply()`
  * [ ] Block for ethers being sent to this contract
  * [ ] `transfer(...)` from one account to another
  * [ ] `approve(...)` and `transferFrom(...)` from one account to another
  * [ ] `transferOwnership(...)` and `acceptOwnership()` of the token contract
  * [ ] `moveToWaves(...)` with the Waves address where the `WavesTransfer(...)` event is logged
* [ ] The testing has been done using geth v1.6.1-stable-021c3c28/darwin-amd64/go1.8.1 and solc 0.4.11+commit.68ef5810.Darwin.appleclang instead of one of the testing frameworks and JavaScript VMs to simulate the live environment as closely as possible
* [ ] The `approveAndCall(...)` function has been omitted from this token smart contract as the side effects of this function has not been evaluated fully
* [ ] There is no logic with potential division by zero errors
* [ ] All numbers used are uint256 (with the exception of `decimals`), reducing the risk of errors from type conversions
* [ ] Areas with potential overflow errors in `transfer(...)` and `transferFrom(...)` have the logic to prevent overflows
* [ ] Areas with potential underflow errors in `transfer(...)` and `transferFrom(...)` have the logic to prevent underflows
* [ ] Function and event names are differentiated by case - function names begin with a lowercase character and event names begin with an uppercase character
* [ ] A default constructor has been added to reject any ethers being received by this smart contract
* [ ] The function `transferAnyERC20Token(...)` has been added in case the owner has to free any accidentally trapped ERC20 tokens
* [ ] The test results can be found in [test/test1results.txt](test/test1results.txt) for the results and [test/test1output.txt](test/test1output.txt) for the full output

<br />

### Risks

* This token contract will not hold any ethers
* In the case where a security vulnerability in this contract is discovered or exploited, a new token contract can be deployed to a new address with the correct(ed) balances transferred over from the old contract to the new contract

<br />

<hr />

### Other Notes

* This token contract has been developed and tested by Alex Kampa and Bok Consulting Pty Ltd
* The security testing and audit has been conducted by Bok Consulting Pty Ltd

<br />

<hr />

## Comments On The Source Code

My comments in the following code are market in the lines beginning with `// NOTE: `.

Following is the source code for [contracts/SikobaContinuousSale.sol](https://github.com/sikoba/token-continuous/blob/68c0a5767829b0fabcf76f07e96bb300f41380dd/contracts/SikobaContinuousSale.sol): 

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
    uint256 _totalSupply = 0;

    // ------------------------------------------------------------------------
    // Balances for each account
    // ------------------------------------------------------------------------
    mapping(address => uint256) balances;

    // ------------------------------------------------------------------------
    // Owner of account approves the transfer of an amount to another account
    // ------------------------------------------------------------------------
    mapping(address => mapping (address => uint256)) allowed;

    // ------------------------------------------------------------------------
    // Get the total token supply
    // ------------------------------------------------------------------------
    function totalSupply() constant returns (uint256 totalSupply) {
        totalSupply = _totalSupply;
    }

    // ------------------------------------------------------------------------
    // Get the account balance of another account with address _owner
    // ------------------------------------------------------------------------
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from owner's account to another account
    // ------------------------------------------------------------------------
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
    string public constant symbol = "SKO1";
    string public constant name = "Sikoba Continuous Sale";
    uint8 public constant decimals = 18;

    // Thursday, 01-Jun-17 00:00:00 UTC
    uint256 public constant START_DATE = 1496275200;

    // Tuesday, 31-Oct-17 23:59:59 UTC
    uint256 public constant END_DATE = 1509494399;

    // number of SKO1 units per ETH at beginning and end
    uint256 public constant START_SKO1_UNITS = 1650;
    uint256 public constant END_SKO1_UNITS = 1200;

    // maximum funding in USD
    uint256 public constant MAX_USD_FUNDING = 400000;

    // Minimum contribution amount is 0.01 ETH
    uint256 public constant MIN_CONTRIBUTION = 10**16;

    uint256 public totalUsdFunding;
    bool public maxUsdFundingReached = false;
    uint256 public usdPerHundredETH;
    uint256 public softEndDate = END_DATE;

    // Ethers contributed and withdrawn
    uint256 public ethersContributed = 0;

    // status variables
    bool public mintingCompleted = false;
    bool public fundingPaused = false;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    event UsdRateSet(uint256 timestamp, uint256 value);
    event TokensBought(address indexed buyer, uint256 ethers, uint256 tokens, 
          uint256 newTotalSupply, uint256 unitsPerEth);

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function SikobaContinuousSale() {
    }

    // ------------------------------------------------------------------------
    // Owner sets the USD rate per 100 ETH - used to determine the funding cap
    // ------------------------------------------------------------------------
    function setUsdPerHundredETH(uint256 value) external onlyOwner {
        usdPerHundredETH = value; // if coinmarketcap $131.14 then send 13114
        UsdRateSet(now, value);
    }

    // ------------------------------------------------------------------------
    // Calculate the number of tokens per ETH contributed
    // Linear (START_DATE, START_SKO1_UNITS) -> (END_DATE, END_SKO1_UNITS)
    // ------------------------------------------------------------------------
    function unitsPerEth(uint256 at) constant returns (uint256) {
        return START_SKO1_UNITS * 10**18 
            + (END_SKO1_UNITS - START_SKO1_UNITS) * 10**18 
            * (at - START_DATE) / (END_DATE - START_DATE);
    }

    // ------------------------------------------------------------------------
    // Buy tokens from the contract
    // ------------------------------------------------------------------------
    function () payable {
        buyTokens();
    }

    function buyTokens() payable {
        // check conditions
        if (fundingPaused) throw;
        if (now < START_DATE) throw;
        if (now > END_DATE) throw;
        if (now > softEndDate) throw;
        if (msg.value < MIN_CONTRIBUTION) throw; // at least ETH 0.01

        // issue tokens
        uint256 _unitsPerEth = unitsPerEth(now);
        uint256 tokens = msg.value * _unitsPerEth / 10**18;
        _totalSupply += tokens;
        balances[msg.sender] += tokens;
        Transfer(0, this, tokens);
        Transfer(this, msg.sender, tokens);

        // approximative funding in USD
        totalUsdFunding += msg.value * usdPerHundredETH / 10**20;
        if (!maxUsdFundingReached && totalUsdFunding > MAX_USD_FUNDING) {
            softEndDate = now + 24*60*60;
            maxUsdFundingReached = true;
        }

        ethersContributed += msg.value;
        TokensBought(msg.sender, msg.value, tokens, _totalSupply, _unitsPerEth);

        // send balance to owner
        owner.transfer(this.balance);
    }

    // ------------------------------------------------------------------------
    // Pause and restart funding
    // ------------------------------------------------------------------------
    function pause() external onlyOwner {
        fundingPaused = true;
    }

    function restart() external onlyOwner {
        fundingPaused = false;
    }


    // ------------------------------------------------------------------------
    // Owner can mint tokens for contributions made outside the ETH contributed
    // to this token contract. This can only occur until mintingCompleted is
    // true
    // ------------------------------------------------------------------------
    function mint(address participant, uint256 tokens) onlyOwner {
        if (mintingCompleted) throw;
        balances[participant] += tokens;
        _totalSupply += tokens;
        Transfer(0, this, tokens);
        Transfer(this, participant, tokens);
    }

    function setMintingCompleted() onlyOwner {
        mintingCompleted = true;
    }
}
```

<br />

<hr />

## References

* [Ethereum Contract Security Techniques and Tips](https://github.com/ConsenSys/smart-contract-best-practices)
* Solidity [bugs.json](https://github.com/ethereum/solidity/blob/develop/docs/bugs.json) and [bugs_by_version.json](https://github.com/ethereum/solidity/blob/develop/docs/bugs_by_version.json).

<br />

(c) BokkyPooBah / Bok Consulting Pty Ltd for Sikoba - May 27 2017
