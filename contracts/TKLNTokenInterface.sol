pragma solidity 0.4.18;
import './Owned.sol';
import './CrowdsaleParameters.sol';

contract TKLNToken is Owned, CrowdsaleParameters {
    string public standard = 'Token 0.1';
    string public name = 'Taklimakan';
    string public symbol = 'TKLN';
    uint8 public decimals = 18;
    uint256 public totalSupply = 0;
    bool public transfersEnabled = true;

    function approveCrowdsale(address _crowdsaleAddress) external;
    function approvePresale(address _presaleAddress) external;
    function balanceOf(address _address) public constant returns (uint256 balance);
    function vestedBalanceOf(address _address) public constant returns (uint256 balance);
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _currentValue, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function toggleTransfers(bool _enable) external;
    function closePresale() external;
    function closeGeneralSale() external;
}
