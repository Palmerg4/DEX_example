pragma solidity >=0.6.0 <0.8.1;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
//import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

contract Rep is ERC20{
  constructor() ERC20('Augur token', 'REP') public {
  }

  function faucet(address to, uint amount) external {
    _mint(to, amount);
  }
}