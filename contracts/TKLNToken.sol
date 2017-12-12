pragma solidity 0.4.18;
import './Owned.sol';
import './CrowdsaleParameters.sol';

contract TKLNToken is Owned, CrowdsaleParameters {
    /* Public variables of the token */
    string public standard = 'Token 0.1';
    string public name = 'Taklimakan';
    string public symbol = 'TKLN';
    uint8 public decimals = 18;

    /* Arrays of all balances, vesting, approvals, and approval uses */
    mapping (address => uint256) private balances;              // Total token balances
    mapping (address => uint256) private balances90dayFreeze;   // Balances frozen for 90 days after ICO end
    mapping (address => uint256) private balances180dayFreeze;  // Balances frozen for 180 days after ICO end
    mapping (address => uint) private vestingTimesForPools;
    mapping (address => mapping (address => uint256)) private allowed;
    mapping (address => mapping (address => bool)) private allowanceUsed;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Transfer(address indexed spender, address indexed from, address indexed to, uint256 value);
    event VestingTransfer(address indexed from, address indexed to, uint256 value, uint256 vestingTime);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Issuance(uint256 _amount); // triggered when the total supply is increased
    event Destruction(uint256 _amount); // triggered when the total supply is decreased
    event NewTKLNToken(address _token);

    /* Miscellaneous */
    uint256 public totalSupply = 0;
    bool public transfersEnabled = true;

    /**
    *  Constructor
    *
    *  Initializes contract with initial supply tokens to the creator of the contract
    */
    function TKLNToken() public {
        owner = msg.sender;

        mintToken(presaleWallet);
        mintToken(generalSaleWallet);
        mintToken(wallet1);
        mintToken(wallet2);
        mintToken(wallet3);
        mintToken(wallet4);
        mintToken(wallet5);
        mintToken(wallet6);
        mintToken(foundersWallet);
        mintToken(wallet7);
        mintToken(wallet8genesis);
        mintToken(wallet9);
        mintToken(wallet10);
        mintToken(wallet11bounty);
        mintToken(wallet12);
        mintToken(wallet13rsv);
        mintToken(wallet14partners);
        mintToken(wallet15lottery);

        NewTKLNToken(address(this));
    }

    modifier transfersAllowed {
        require(transfersEnabled);
        _;
    }

    modifier onlyPayloadSize(uint size) {
        assert(msg.data.length >= size + 4);
        _;
    }

    /**
    *  1. Associate crowdsale contract address with this Token
    *  2. Allocate general sale amount
    *
    * @param _crowdsaleAddress - crowdsale contract address
    */
    function approveCrowdsale(address _crowdsaleAddress) external onlyOwner {
        approveAllocation(generalSaleWallet, _crowdsaleAddress);
    }

    /**
    *  1. Associate pre-sale contract address with this Token
    *  2. Allocate presale amount
    *
    * @param _presaleAddress - pre-sale contract address
    */
    function approvePresale(address _presaleAddress) external onlyOwner {
        approveAllocation(presaleWallet, _presaleAddress);
    }

    function approveAllocation(AddressTokenAllocation tokenAllocation, address _crowdsaleAddress) internal {
        uint uintDecimals = decimals;
        uint exponent = 10**uintDecimals;
        uint amount = tokenAllocation.amount * exponent;

        allowed[tokenAllocation.addr][_crowdsaleAddress] = amount;
        Approval(tokenAllocation.addr, _crowdsaleAddress, amount);
    }

    /**
    *  Get token balance of an address
    *
    * @param _address - address to query
    * @return Token balance of _address
    */
    function balanceOf(address _address) public constant returns (uint256 balance) {
        return balances[_address];
    }

    /**
    *  Get vested token balance of an address
    *
    * @param _address - address to query
    * @return balance that has vested
    */
    function vestedBalanceOf(address _address) public constant returns (uint256 balance) {
        return balances[_address] - balances90dayFreeze[_address] - balances180dayFreeze[_address];
    }

    /**
    *  Get token amount allocated for a transaction from _owner to _spender addresses
    *
    * @param _owner - owner address, i.e. address to transfer from
    * @param _spender - spender address, i.e. address to transfer to
    * @return Remaining amount allowed to be transferred
    */
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /**
    *  Send coins from sender's address to address specified in parameters
    *
    * @param _to - address to send to
    * @param _value - amount to send in Wei
    */
    function transfer(address _to, uint256 _value) public transfersAllowed onlyPayloadSize(2*32) returns (bool success) {
        updateVesting(msg.sender);

        require(vestedBalanceOf(msg.sender) >= _value);

        // Subtract from the sender
        // _value is never greater than balance of input validation above
        balances[msg.sender] -= _value;

        // If tokens issued from this address need to vest (i.e. this address is a pool), freeze them here
        if (vestingTimesForPools[msg.sender] > 0) {
            addToVesting(msg.sender, _to, vestingTimesForPools[msg.sender], _value);
        }

        // Overflow is never possible due to input validation above
        balances[_to] += _value;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    *  Create token and credit it to target address
    *  Created tokens need to vest
    *
    */
    function mintToken(AddressTokenAllocation tokenAllocation) internal {
        // Add vesting time for this pool
        vestingTimesForPools[tokenAllocation.addr] = tokenAllocation.vestingTS;

        uint uintDecimals = decimals;
        uint exponent = 10**uintDecimals;
        uint mintedAmount = tokenAllocation.amount * exponent;

        // Mint happens right here: Balance becomes non-zero from zero
        balances[tokenAllocation.addr] += mintedAmount;
        totalSupply += mintedAmount;

        // Emit Issue and Transfer events
        Issuance(mintedAmount);
        Transfer(address(this), tokenAllocation.addr, mintedAmount);
    }

    /**
    *  Allow another contract to spend some tokens on your behalf
    *
    * @param _spender - address to allocate tokens for
    * @param _value - number of tokens to allocate
    * @return True in case of success, otherwise false
    */
    function approve(address _spender, uint256 _value) public onlyPayloadSize(2*32) returns (bool success) {
        require(_value == 0 || allowanceUsed[msg.sender][_spender] == false);

        allowed[msg.sender][_spender] = _value;
        allowanceUsed[msg.sender][_spender] = false;
        Approval(msg.sender, _spender, _value);

        return true;
    }

    /**
    *  Allow another contract to spend some tokens on your behalf
    *
    * @param _spender - address to allocate tokens for
    * @param _currentValue - current number of tokens approved for allocation
    * @param _value - number of tokens to allocate
    * @return True in case of success, otherwise false
    */
    function approve(address _spender, uint256 _currentValue, uint256 _value) public onlyPayloadSize(3*32) returns (bool success) {
        require(allowed[msg.sender][_spender] == _currentValue);
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
    *  A contract attempts to get the coins. Tokens should be previously allocated
    *
    * @param _to - address to transfer tokens to
    * @param _from - address to transfer tokens from
    * @param _value - number of tokens to transfer
    * @return True in case of success, otherwise false
    */
    function transferFrom(address _from, address _to, uint256 _value) public transfersAllowed onlyPayloadSize(3*32) returns (bool success) {
        updateVesting(_from);

        // Check if the sender has enough
        require(vestedBalanceOf(_from) >= _value);

        // Check allowed
        require(_value <= allowed[_from][msg.sender]);

        // Subtract from the sender
        // _value is never greater than balance because of input validation above
        balances[_from] -= _value;
        // Add the same to the recipient
        // Overflow is not possible because of input validation above
        balances[_to] += _value;

        // Deduct allocation
        // _value is never greater than allowed amount because of input validation above
        allowed[_from][msg.sender] -= _value;

        // If tokens issued from this address need to vest (i.e. this address is a pool), freeze them here
        if (vestingTimesForPools[_from] > 0) {
            addToVesting(_from, _to, vestingTimesForPools[_from], _value);
        }

        Transfer(msg.sender, _from, _to, _value);
        allowanceUsed[_from][msg.sender] = true;

        return true;
    }

    /**
    *  Default method
    *
    *  This unnamed function is called whenever someone tries to send ether to
    *  it. Just revert transaction because there is nothing that Token can do
    *  with incoming ether.
    *
    *  Missing payable modifier prevents accidental sending of ether
    */
    function() public {
    }

    /**
    *  Enable or disable transfers
    *
    * @param _enable - True = enable, False = disable
    */
    function toggleTransfers(bool _enable) external onlyOwner {
        transfersEnabled = _enable;
    }

    /**
    *  Destroy unsold preICO tokens
    *
    */
    function closePresale() external onlyOwner {
        // Destroyed amount is never greater than total supply,
        // so no underflow possible here
        uint destroyedAmount = balances[presaleWallet.addr];
        totalSupply -= destroyedAmount;
        balances[presaleWallet.addr] = 0;
        Destruction(destroyedAmount);
        Transfer(presaleWallet.addr, 0x0, destroyedAmount);
    }

    /**
    *  Destroy unsold general sale tokens
    *
    */
    function closeGeneralSale() external onlyOwner {
        // Destroyed amount is never greater than total supply,
        // so no underflow possible here
        uint destroyedAmount = balances[generalSaleWallet.addr];
        totalSupply -= destroyedAmount;
        balances[generalSaleWallet.addr] = 0;
        Destruction(destroyedAmount);
        Transfer(generalSaleWallet.addr, 0x0, destroyedAmount);
    }

    function addToVesting(address _from, address _target, uint256 _vestingTime, uint256 _amount) internal {
        if (CrowdsaleParameters.vestingTime90Days == _vestingTime) {
            balances90dayFreeze[_target] += _amount;
            VestingTransfer(_from, _target, _amount, _vestingTime);
        } else if (CrowdsaleParameters.vestingTime180Days == _vestingTime) {
            balances180dayFreeze[_target] += _amount;
            VestingTransfer(_from, _target, _amount, _vestingTime);
        }
    }

    function updateVesting(address sender) internal {
        if (CrowdsaleParameters.vestingTime90Days < now) {
            balances90dayFreeze[sender] = 0;
        }
        if (CrowdsaleParameters.vestingTime180Days < now) {
            balances180dayFreeze[sender] = 0;
        }
    }
}
