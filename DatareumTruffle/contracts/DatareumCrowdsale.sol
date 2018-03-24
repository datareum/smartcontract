pragma solidity ^0.4.20;
import "./Oraclize.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

//Abstract Token contract
contract DatareumToken{
  function setCrowdsaleContract (address) public;
  function sendCrowdsaleTokens(address, uint256)  public;
  // function setIcoFinishedTrue () public;
  function endICO () public;

}

//Crowdsale contract
contract DatareumCrowdsale is Ownable, usingOraclize{

  using SafeMath for uint;

  uint decimals = 18;

  // Token contract address
  DatareumToken public token;

  uint public startingExchangePrice = 1165134514779731;
  uint public tokenPrice; //0.03USD

  address public distributionAddress;

  // Constructor
  function DatareumCrowdsale(address _tokenAddress, address _distribution) public payable{
    token = DatareumToken(_tokenAddress);
    owner = msg.sender;

    distributionAddress = _distribution;

    token.setCrowdsaleContract(this);
    
    oraclize_setNetwork(networkID_auto);
    oraclize = OraclizeI(OAR.getAddress());
    
    tokenPrice = startingExchangePrice*3/100;

    oraclizeBalance = msg.value;
    
    uint eleven = 1521586800; // Put the erliest 11pm timestamp
    
    updateFlag = true;
    oraclize_query((findElevenPmUtc(eleven)),"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    oraclizeBalance = oraclizeBalance.add(oraclize_getPrice("URL"));
  }

  function getPreIcoBonus(uint _value) public pure returns(uint) {
    if(_value < 5 ether){
      return 10;
    }
    return 20;
  }

  function getIcoBonus () public pure returns(uint) {
    return 0;
  }
  

  //PRE ICO CONSTANTS
  uint public constant PRE_ICO_MIN_DEPOSIT = 1 ether; 

  uint public constant PRE_ICO_MIN_CAP = 0;
  uint public PRE_ICO_MAX_CAP = startingExchangePrice.mul((uint)(2000000)); //2 000 000 USD

  uint public constant PRE_ICO_START = 0; //1524916800
  uint public constant PRE_ICO_FINISH = 1525737540;
  //END PRE ICO CONSTANTS

  //ICO CONSTANTS
  uint public constant ICO_MIN_DEPOSIT = 0.1 ether;
  // uint public constant ICO_MAX_DEPOSIT = 100 ether;

  uint public ICO_MIN_CAP = startingExchangePrice.mul((uint)(5000000)); // 500 000 USD
  // uint public constant ICO_MAX_CAP = 2000000 ether;


  //END ICO CONSTANTS

  uint public ICO_START = 1527940800; //1527940800;
  uint public ICO_FINISH = 1530575940; //1530575940;

  function setIcoPhase (uint _start, uint _finish) public onlyOwner {
    require (ICO_START == ICO_FINISH);
    ICO_START = _start;
    ICO_FINISH = _finish;    
  }
  
  function getPhase(uint _time) public view returns(uint8) {
    if(_time == 0){
      _time = now;
    }
    if (PRE_ICO_START <= _time && _time < PRE_ICO_FINISH){
      return 1;
    }
    if (ICO_START <= _time && _time < ICO_FINISH){
      return 2;
    }
    return 0;
  }

  uint public ethCollected = 0;

  mapping (address => uint) public contributorEthCollected;
  
  mapping (address => bool) public whiteList;

  event addToWhiteListEvent(address _address);
  event removeFromWhiteListEvent(address _address);
  
  
  function addToWhiteList(address[] _addresses) public onlyOwnerOrSubOwners {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = true;
      emit addToWhiteListEvent(_addresses[i]);
    }
  }

  function removeFromWhiteList (address[] _addresses) public onlyOwnerOrSubOwners {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = false;
      emit removeFromWhiteListEvent(_addresses[i]);
    }
  }

  event OnSuccessBuy (address indexed _address, uint indexed _EthValue, uint indexed _percent, uint _tokenValue);

  function () public payable {
    require (whiteList[msg.sender]);
    require (buy(msg.sender, msg.value, now));

  }

  function buy (address _address, uint _value, uint _time) internal returns(bool)  {
    uint8 currentPhase = getPhase(_time);
    require (currentPhase > 0);

    if(funders[_address].active && _value >= funders[_address].amount){
      uint bufferTokens = funders[_address].amount.mul((uint)(10).pow(decimals)/tokenPrice);
      bufferTokens = bufferTokens.add(bufferTokens.mul(funders[_address].bonus)/100);

      uint bufferEth = _value.sub(funders[_address].amount);
      bufferTokens = bufferTokens.add(bufferEth.mul((uint)(10).pow(decimals))/100); 

      token.sendCrowdsaleTokens(_address,bufferTokens);
      
      ethCollected = ethCollected.add(_value);

      if (ethCollected >= ICO_MIN_CAP){
        distributionAddress.transfer(address(this).balance.sub(oraclizeBalance));
      }
      funders[_address].active = false;

      emit OnSuccessBuy(_address, _value, 0, bufferTokens);
      return true;
    }


    uint bonusPercent = 0;

    ethCollected = ethCollected.add(_value);

    uint tokensToSend = (_value.mul((uint)(10).pow(decimals))/tokenPrice);

    if (currentPhase == 1){
      require (_value >= PRE_ICO_MIN_DEPOSIT);

      bonusPercent = getPreIcoBonus(_value);

      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);

      require (ethCollected.add(_value) <= PRE_ICO_MAX_CAP);

      if (ethCollected >= PRE_ICO_MIN_CAP){
        distributionAddress.transfer(address(this).balance.sub(oraclizeBalance));
      }

    }else if(currentPhase == 2){
      require (_value >= ICO_MIN_DEPOSIT);

      contributorEthCollected[_address] = contributorEthCollected[_address].add(_value);

      bonusPercent = getIcoBonus();

      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);

      if (ethCollected >= ICO_MIN_CAP){
        distributionAddress.transfer(address(this).balance.sub(oraclizeBalance));
      }
    }

    token.sendCrowdsaleTokens(_address,tokensToSend);

    emit OnSuccessBuy(_address, _value, bonusPercent, tokensToSend);

    return true;
  }

  function tokenCalculate (uint _value) public view returns(uint)  {
    uint bonusPercent;
    uint tokensToSend = (_value.mul((uint)(10).pow(decimals))/tokenPrice);

    if (now < PRE_ICO_FINISH){
      require (_value >= PRE_ICO_MIN_DEPOSIT);

      bonusPercent = getPreIcoBonus(_value);
      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);
    }else if(now >= PRE_ICO_FINISH){
      require (_value >= ICO_MIN_DEPOSIT);

      bonusPercent = getIcoBonus();
      tokensToSend = tokensToSend.add(tokensToSend.mul(bonusPercent)/100);
    }
    return tokensToSend;
  }
  
  function manualSendTokens (address _address, uint _value) public onlyOwnerOrSubOwners {
    token.sendCrowdsaleTokens(_address,_value.mul((uint)(10).pow(decimals))/tokenPrice);
    ethCollected = ethCollected.add(_value);
  }
  
  uint public priceUpdateAt = 0;
  
  event newPriceTicker(string price);
  
  function __callback(bytes32, string result, bytes) public {
    require(msg.sender == oraclize_cbAddress());

    uint256 price = 10 ** 23 / parseInt(result, 5);

    require(price > 0);
    // currentExchangePrice = price;
    tokenPrice = price*3/100;
    
    PRE_ICO_MAX_CAP = price.mul((uint)(2000000)); //2 000 000 USD
    ICO_MIN_CAP = price.mul((uint)(500000)); //500 000 USD


    priceUpdateAt = block.timestamp;
        
    emit newPriceTicker(result);
    
    if(updateFlag){
      update();
    }
  }
  
  bool public updateFlag = false;
  
  function update() internal {
    oraclize_query(86400,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    //86400 - 1 day
  
    oraclizeBalance = oraclizeBalance.sub(oraclize_getPrice("URL")); //request to oraclize
  }
  

  uint public oraclizeBalance = 0;

  function addEtherForOraclize () public payable {
    oraclizeBalance = oraclizeBalance.add(msg.value);
  }

  function requestOraclizeBalance () public onlyOwner {
    updateFlag = false;
    if (address(this).balance >= oraclizeBalance){
      owner.transfer(oraclizeBalance);
    }else{
      owner.transfer(address(this).balance);
    }
    oraclizeBalance = 0;
  }
  
  function stopOraclize () public onlyOwnerOrSubOwners {
    updateFlag = false;
  }

  function findElevenPmUtc (uint eleven) public view returns (uint) {
    for (uint i = 0; i < 300; i++){
      if(eleven > now){
        return eleven.sub(now);
      }
      eleven = eleven + 1 days;
    }
    return 0;
  }

  function startOraclize (uint _time) public onlyOwnerOrSubOwners {
    require (_time != 0);
    require (!updateFlag);
    
    updateFlag = true;
    oraclize_query(_time,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    oraclizeBalance = oraclizeBalance.sub(oraclize_getPrice("URL"));
  }

  function refund () public {
    require (now > ICO_FINISH && ethCollected < ICO_MIN_CAP);
    require (contributorEthCollected[msg.sender] > 0);

    msg.sender.transfer(contributorEthCollected[msg.sender]);
    contributorEthCollected[msg.sender] = 0;
  }

  function endICO () public onlyOwner {
    require (now > ICO_FINISH && now > PRE_ICO_FINISH);
    token.endICO();
  }
  
  mapping (address => bool) public subOwners;
  modifier onlyOwnerOrSubOwners() { 
    require (subOwners[msg.sender] || msg.sender == owner); 
    _; 
  }
  
  struct Funder {
    uint amount;
    uint bonus;
    bool active;
  }
  
  mapping (address => Funder) public funders;

  function addFunder (address _address, uint _amount, uint _bonus) public onlyOwnerOrSubOwners {
    funders[_address] = Funder(_amount,_bonus,true);
  }
  function removeFunder (address _address) public onlyOwnerOrSubOwners {
    Funder memory buffer = funders[_address];
    buffer.active = false;
    funders[_address] = buffer;
  }
}