pragma solidity 0.4.18;
import './Owned.sol';
import './TKLNToken.sol';
import './TaklimakanCrowdsale.sol';

contract TaklimakanPreICO is TaklimakanCrowdsale {
    /**
    * Constructor
    *
    * @param _tokenAddress - address of token (deployed before this contract)
    */
    function TaklimakanPreICO(address _tokenAddress) TaklimakanCrowdsale(_tokenAddress) public {
        saleWalletAddress = CrowdsaleParameters.presaleWallet.addr;

        saleStartTimestamp = CrowdsaleParameters.presaleStartDate;
        saleStopTimestamp = CrowdsaleParameters.presaleEndDate;

        // Initialize sale goal
        saleGoal = CrowdsaleParameters.presaleWallet.amount;
        stageBonus = 2;
    }

    /**
    *  Allow anytime withdrawals
    *
    * @param amount - ETH amount to transfer in Wei
    */
    function safeWithdrawal(uint amount) external onlyOwner {
        require(this.balance >= amount);

        if (owner.send(amount)) {
            FundTransfer(address(this), msg.sender, amount);
        }
    }

    /**
    *  Refund
    *
    *  Pre ICO refunds are not provided
    */
    function refund() external {
        revert();
    }
}
