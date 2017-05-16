pragma solidity ^0.4.8;

/**
 * SIKOBA PRESALE CONTRACTS
 *
 * Version 0.1
 *
 * Authors Bok 'BokkyPooBah' Khoo, Alex Kampa
 *
 * MIT LICENSE Copyright 2017 Sikoba Ltd
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 **/


/**
 *
 * Important information
 *
 * For details about the Sikoba continuous token sale, and in particular to find 
 * out about risks and limitations, please visit:
 *
 * http://www.sikoba.com/www/presale/index.html
 *
 **/
 
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


// ERC Token Standard #20 - https://github.com/ethereum/EIPs/issues/20
contract ERC20Token is Owned {
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
    function transfer(address _to, uint256 _amount) returns (bool success) {
        if (balances[msg.sender] >= _amount
            && _amount > 0
            && balances[_to] + _amount > balances[_to]) {
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
    // balance to the spender's account. The owner of the tokens must already
    // have approve(...)-d this transfer
    // ------------------------------------------------------------------------
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) returns (bool success) {
        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0
            && balances[_to] + _amount > balances[_to]) {
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

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender,
        uint256 _value);
}


contract SikobaContinuousSale is ERC20Token {

    // ------------------------------------------------------------------------
    // Token information
    // ------------------------------------------------------------------------
    string public constant symbol = "SKO0";
    string public constant name = "Sikoba Continuous Sale";
    uint8 public constant decimals = 18;

    uint256 public deployedAt;

    function SikobaContinuousSale() {
        deployedAt = now;
    }


    // ------------------------------------------------------------------------
    // Members buy tokens from this contract at this price
    //
    // This is a maximum price that the tokens should be bought at, as buyers
    // can always buy tokens from this contract for this price
    //
    // Check out the BERP prices on https://cryptoderivatives.market/ to see
    // if you can buy these tokens for less than this maximum price
    // ------------------------------------------------------------------------
    function buyPrice() constant returns (uint256) {
        return buyPriceAt(now);
    }

    function buyPriceAt(uint256 at) constant returns (uint256) {
        if (at < (deployedAt + 7 days)) {
            return 10 * 10**14;
        } else if (at < (deployedAt + 30 days)) {
            return 11 * 10**14;
        } else if (at < (deployedAt + 60 days)) {
            return 12 * 10**15;
        } else if (at < (deployedAt + 90 days)) {
            return 13 * 10**15;
        } else if (at < (deployedAt + 365 days)) {
            return 15 * 10**16;
        } else {
            return 10**21;
        }
    }


    // ------------------------------------------------------------------------
    // Buy tokens from the contract
    // ------------------------------------------------------------------------
    function () payable {
        buyTokens();
    }

    function buyTokens() payable {
        if (msg.value > 0) {
            uint tokens = msg.value * 1 ether / buyPrice();
            _totalSupply += tokens;
            balances[msg.sender] += tokens;
            TokensBought(msg.sender, msg.value, this.balance, tokens,
                 _totalSupply, buyPrice());
        }
    }
    event TokensBought(address indexed buyer, uint256 ethers, 
        uint256 newEtherBalance, uint256 tokens, uint256 newTotalSupply, 
        uint256 buyPrice);


    // ------------------------------------------------------------------------
    // Sell tokens to the contract
    // ------------------------------------------------------------------------
    function sellTokens(uint256 amountOfTokens) {
        if (amountOfTokens > balances[msg.sender]) throw;
        balances[msg.sender] -= amountOfTokens;
        _totalSupply -= amountOfTokens;
        uint256 ethersToSend = amountOfTokens * sellPrice() / 1 ether;
        if (!msg.sender.send(ethersToSend)) throw;
        TokensSold(msg.sender, ethersToSend, this.balance, amountOfTokens,
            _totalSupply, sellPrice());
    }
    event TokensSold(address indexed seller, uint256 ethers, 
        uint256 newEtherBalance, uint256 tokens, uint256 newTotalSupply, 
        uint256 sellPrice);

/*
    // ------------------------------------------------------------------------
    // Owner Withdrawal
    // ------------------------------------------------------------------------
    function ownerWithdraw(uint256 amount) onlyOwner {
        uint256 maxWithdrawalAmount = amountOfEthersOwnerCanWithdraw();
        if (amount > this.balance) {
            amount = this.balance;
        }
        if (!owner.send(amount)) throw;
        Withdrawn(amount, maxWithdrawalAmount - amount);
    }
    event Withdrawn(uint256 amount, uint256 remainingWithdrawal);
    */
}
 
