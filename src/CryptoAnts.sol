// TODO: [x] Work on storage padding
// TODO: [ ] Circular deployment, since we need to pass this contract's address to build the Egg
// TODO: [x] Maybe this variable is not necessary
// TODO: [ ] This calculation is unsafe
// TODO: [ ] Need a check to know if the mint call reverted
// TODO: [ ] Need a check to see if the user has enough eggs
// TODO: [ ] This code looks weird and spaghetti-like
// TODO: [ ] Replace requires with reverts+error
// TODO: [ ] solhint-disable-next-line
// TODO: [ ] This does not work "delete"

import '@openzeppelin/access/Ownable.sol';
import '@openzeppelin/token/ERC20/IERC20.sol';
import '@openzeppelin/token/ERC721/ERC721.sol';
import '@openzeppelin/token/ERC721/IERC721.sol';
import '@openzeppelin/utils/ReentrancyGuard.sol';
import 'forge-std/console.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);

  function buyEggs(uint256) external payable;

  error NoEggs();

  event AntSold();

  error NoZeroAddress();

  event AntCreated();

  error AlreadyExists();
  error WrongEtherSent();
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts, Ownable, ReentrancyGuard {
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  mapping(uint256 => address) public antToOwner;
  uint256[] public allAntsIds;
  IEgg public immutable eggs;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') Ownable(msg.sender) {
    eggs = IEgg(_eggs);
  }

  function setEggPrice(uint256 _price) external onlyOwner {
    eggPrice = _price;
  }

  function buyEggs(uint256 _amount) external payable override nonReentrant {
    uint256 _eggPrice = eggPrice;
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = ++antsCreated;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function sellAnt(uint256 _antId) external {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    (bool success,) = msg.sender.call{value: 0.004 ether}('');
    require(success, 'Whoops, this call failed!');
    delete antToOwner[_antId];
    _burn(_antId);
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }
}
