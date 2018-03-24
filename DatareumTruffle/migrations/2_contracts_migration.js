var Token = artifacts.require("./DatareumToken.sol");
var Crowdsale = artifacts.require("./DatareumCrowdsale.sol");

// var address = web3.eth.accounts[0];
module.exports = function(deployer) {
  deployer.deploy(Token,"0xBBBBaAeDaa53EACF57213b95cc023f668eDbA361","0xBBBBaAeDaa53EACF57213b95cc023f668eDbA361").then(function(){
  	return deployer.deploy(Crowdsale,Token.address);
  });
}