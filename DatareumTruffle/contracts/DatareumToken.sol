pragma solidity ^0.4.20;

import "./Ownable.sol";
import "./SafeMath.sol";

contract DatareumToken is Ownable { //ERC - 20 token contract
  using SafeMath for uint;
  // Triggered when tokens are transferred.
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  // Triggered whenever approve(address _spender, uint256 _value) is called.
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  string public constant symbol = "DTR";
  string public constant name = "Datareum";
  uint8 public constant decimals = 18;
  uint256 _totalSupply = 1000000000 ether;

  // Owner of this contract
  address public owner;

  // Balances for each account
  mapping(address => uint256) balances;

  // Owner of account approves the transfer of an amount to another account
  mapping(address => mapping (address => uint256)) allowed;

  function totalSupply() public view returns (uint256) { //standart ERC-20 function
    return _totalSupply;
  }

  function balanceOf(address _address) public view returns (uint256 balance) {//standart ERC-20 function
    return balances[_address];
  }
  
  bool public locked = true;
  function changeLockTransfer (bool _request) public onlyOwner {
    locked = _request;
  }
  
  //standart ERC-20 function
  function transfer(address _to, uint256 _amount) public returns (bool success) {
    require(this != _to);
    require(!locked);
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(msg.sender,_to,_amount);
    return true;
  }

  //standart ERC-20 function
  function transferFrom(address _from, address _to, uint256 _amount) public returns(bool success){
    require(this != _to);
    require(!locked);
    balances[_from] = balances[_from].sub(_amount);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(_from,_to,_amount);
    return true;
  }
  //standart ERC-20 function
  function approve(address _spender, uint256 _amount)public returns (bool success) { 
    allowed[msg.sender][_spender] = _amount;
    emit Approval(msg.sender, _spender, _amount);
    return true;
  }

  //standart ERC-20 function
  function allowance(address _owner, address _spender)public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  //Constructor
  function DatareumToken() public {
    owner = msg.sender;
    balances[this] = _totalSupply;
  }

  address public crowdsaleContract;

  function setCrowdsaleContract (address _address) public{
    require(crowdsaleContract == address(0));

    crowdsaleContract = _address;
  }

  function endICO (uint _date) public {
    require(msg.sender == crowdsaleContract);
    balances[this] = balances[this].sub(crowdsaleBalance);
    emit Transfer(this,0,crowdsaleBalance);
    
    crowdsaleBalance = 0;
    finishDate = _date;
  }

  uint finishDate = 1893456000;
  
  uint public crowdsaleBalance = 600000000 ether;
  
  function sendCrowdsaleTokens (address _address, uint _value) public {
    require(msg.sender == crowdsaleContract);

    balances[this] = balances[this].sub(_value);
    balances[_address] = balances[_address].add(_value);
    
    crowdsaleBalance = crowdsaleBalance.sub(_value);
    
    emit Transfer(this,_address,_value);    
  }

  uint public advisorsBalance = 200000000 ether;
  uint public foundersBalance = 100000000 ether;
  uint public futureFundingBalance = 50000000 ether;
  uint public bountyBalance = 50000000 ether;

  function sendAdvisorsBalance (address[] _addresses, uint[] _values) public onlyOwner {
    require(crowdsaleBalance == 0);
    uint buffer = 0;
    for(uint i = 0; i < _addresses.length; i++){
      balances[_addresses[i]] = balances[_addresses[i]].add(_values[i]);
      buffer = buffer.add(_values[i]);
      emit Transfer(this,_addresses[i],_values[i]);
    }
    advisorsBalance = advisorsBalance.sub(buffer);
    balances[this] = balances[this].sub(buffer);
  }
  
  function sendFoundersBalance (address[] _addresses, uint[] _values) public onlyOwner {
    require(crowdsaleBalance == 0);
    require(now > finishDate + 1 years);

    uint buffer = 0;
    for(uint i = 0; i < _addresses.length; i++){
      balances[_addresses[i]] = balances[_addresses[i]].add(_values[i]);
      buffer = buffer.add(_values[i]);
      emit Transfer(this,_addresses[i],_values[i]);
    }
    foundersBalance = foundersBalance.sub(buffer);
    balances[this] = balances[this].sub(buffer);
  }

  function sendFutureFundingBalance (address[] _addresses, uint[] _values) public onlyOwner {
    require(crowdsaleBalance == 0);
    require(now > finishDate + 2 years);

    uint buffer = 0;
    for(uint i = 0; i < _addresses.length; i++){
      balances[_addresses[i]] = balances[_addresses[i]].add(_values[i]);
      buffer = buffer.add(_values[i]);
      emit Transfer(this,_addresses[i],_values[i]);
    }
    futureFundingBalance = futureFundingBalance.sub(buffer);
    balances[this] = balances[this].sub(buffer);
  }

  uint public constant PRE_ICO_FINISH = 1525564740;

  mapping (address => bool) bountyAddresses;

  function addBountyAddresses (address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      bountyAddresses[_addresses[i]] = true;
    }
  }

  function removeBountyAddresses (address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      bountyAddresses[_addresses[i]] = false;
    }
  }

  function sendBountyBalance (address[] _addresses, uint[] _values) public {
    require(now >= PRE_ICO_FINISH);
    require (bountyAddresses[msg.sender]);

    uint buffer = 0;
    for(uint i = 0; i < _addresses.length; i++){
      balances[_addresses[i]] = balances[_addresses[i]].add(_values[i]);
      buffer = buffer.add(_values[i]);
      emit Transfer(this,_addresses[i],_values[i]);
    }
    bountyBalance = bountyBalance.sub(buffer);
    balances[this] = balances[this].sub(buffer);
  }
}