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
    uint256 public constant START_DATE = 1495897119; // Sat 27 May 2017 14:58:39 UTC

    // Tuesday, 31-Oct-17 23:59:59 UTC
    uint256 public constant END_DATE = 1495897359; // Sat 27 May 2017 15:02:39 UTC

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
    event UsdRateSet(uint256 value);
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
        UsdRateSet(value);
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