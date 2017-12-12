pragma solidity 0.4.18;
import './Owned.sol';
import './TKLNToken.sol';

contract TaklimakanCrowdsale is Owned, CrowdsaleParameters {
    /* ICO and Pre-ICO Parameters */
    address internal saleWalletAddress;
    uint private tokenMultiplier = 10;
    uint public saleStartTimestamp;
    uint public saleStopTimestamp;
    uint public saleGoal;
    uint8 public stageBonus;
    bool public goalReached = false;

    /* Token and records */
    TKLNToken private token;
    uint public totalCollected = 0;
    mapping (address => uint256) private investmentRecords;

    /* Events */
    event TokenSale(address indexed tokenReceiver, uint indexed etherAmount, uint indexed tokenAmount, uint tokensPerEther);
    event FundTransfer(address indexed from, address indexed to, uint indexed amount);
    event Refund(address indexed backer, uint amount);

    /**
    * Constructor
    *
    * @param _tokenAddress - address of token (deployed before this contract)
    */
    function TaklimakanCrowdsale(address _tokenAddress) public {
        token = TKLNToken(_tokenAddress);
        tokenMultiplier = tokenMultiplier ** token.decimals();
        saleWalletAddress = CrowdsaleParameters.generalSaleWallet.addr;

        saleStartTimestamp = CrowdsaleParameters.generalSaleStartDate;
        saleStopTimestamp = CrowdsaleParameters.generalSaleEndDate;

        // Initialize sale goal
        saleGoal = CrowdsaleParameters.generalSaleWallet.amount;
        stageBonus = 1;
    }

    /**
    * Is sale active
    *
    * @return active - True, if sale is active
    */
    function isICOActive() public constant returns (bool active) {
        active = ((saleStartTimestamp <= now) && (now < saleStopTimestamp) && (!goalReached));
        return active;
    }

    /**
    *  Process received payment
    *
    *  Determine the integer number of tokens that was purchased considering current
    *  stage, tier bonus, and remaining amount of tokens in the sale wallet.
    *  Transfer purchased tokens to bakerAddress and return unused portion of
    *  ether (change)
    *
    * @param bakerAddress - address that ether was sent from
    * @param amount - amount of Wei received
    */
    function processPayment(address bakerAddress, uint amount) internal {
        require(isICOActive());

        // Before Metropolis update require will not refund gas, but
        // for some reason require statement around msg.value always throws
        assert(msg.value > 0 finney);

        // Tell everyone about the transfer
        FundTransfer(bakerAddress, address(this), amount);

        // Calculate tokens per ETH for this tier
        uint tokensPerEth = 16500;

        if (amount < 3 ether)
            tokensPerEth = 15000;
        else if (amount < 7 ether)
            tokensPerEth = 15150;
        else if (amount < 15 ether)
            tokensPerEth = 15300;
        else if (amount < 30 ether)
            tokensPerEth = 15450;
        else if (amount < 75 ether)
            tokensPerEth = 15600;
        else if (amount < 150 ether)
            tokensPerEth = 15750;
        else if (amount < 250 ether)
            tokensPerEth = 15900;
        else if (amount < 500 ether)
            tokensPerEth = 16050;
        else if (amount < 750 ether)
            tokensPerEth = 16200;
        else if (amount < 1000 ether)
            tokensPerEth = 16350;

        tokensPerEth = tokensPerEth * stageBonus;

        // Calculate token amount that is purchased,
        // truncate to integer
        uint tokenAmount = amount * tokensPerEth / 1e18;

        // Check that stage wallet has enough tokens. If not, sell the rest and
        // return change.
        uint remainingTokenBalance = token.balanceOf(saleWalletAddress) / tokenMultiplier;
        if (remainingTokenBalance < tokenAmount) {
            tokenAmount = remainingTokenBalance;
            goalReached = true;
        }

        // Calculate Wei amount that was received in this transaction
        // adjusted to rounding and remaining token amount
        uint acceptedAmount = tokenAmount * 1e18 / tokensPerEth;

        // Transfer tokens to baker and return ETH change
        token.transferFrom(saleWalletAddress, bakerAddress, tokenAmount * tokenMultiplier);
        TokenSale(bakerAddress, amount, tokenAmount, tokensPerEth);

        // Return change
        uint change = amount - acceptedAmount;
        if (change > 0) {
            if (bakerAddress.send(change)) {
                FundTransfer(address(this), bakerAddress, change);
            }
            else revert();
        }

        // Update crowdsale performance
        investmentRecords[bakerAddress] += acceptedAmount;
        totalCollected += acceptedAmount;
    }

    /**
    *  Transfer ETH amount from contract to owner's address.
    *  Can only be used if ICO is closed
    *
    * @param amount - ETH amount to transfer in Wei
    */
    function safeWithdrawal(uint amount) external onlyOwner {
        require(this.balance >= amount);
        require(!isICOActive());
        require(totalCollected >= CrowdsaleParameters.minimumICOCap * 1e18);

        if (owner.send(amount)) {
            FundTransfer(address(this), msg.sender, amount);
        }
    }

    /**
    *  Default method
    *
    *  Processes all ETH that it receives and credits TKLN tokens to sender
    *  according to current stage bonus
    */
    function () external payable {
        processPayment(msg.sender, msg.value);
    }

    /**
    *  Kill method
    *
    *  Destructs this contract
    */
    function kill() external onlyOwner {
        require(!isICOActive());
        selfdestruct(owner);
    }

    /**
    *  Refund
    *
    *  Sends a refund to the sender who calls this method.
    */
    function refund() external {
        require((now > saleStopTimestamp) && (totalCollected < CrowdsaleParameters.minimumICOCap * 1e18));
        require(investmentRecords[msg.sender] > 0);

        var amountToReturn = investmentRecords[msg.sender];

        require(this.balance >= amountToReturn);

        investmentRecords[msg.sender] = 0;
        msg.sender.transfer(amountToReturn);
        Refund(msg.sender, amountToReturn);
    }
}
