//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

// TODO: [x] Work on storage padding
// TODO: [x] Maybe this variable is not necessary
// TODO: [x] This calculation is unsafe
// TODO: [x] Need a check to know if the mint call reverted
// TODO: [x] Need a check to see if the user has enough eggs
// TODO: [x] Replace requires with reverts+error
// TODO: [x] solhint-disable-next-line
// TODO: [ ] Circular deployment, since we need to pass this contract's address to build the Egg
// TODO: [ ] This code looks weird and spaghetti-like
// TODO: [ ] This does not work "delete"

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {IERC721} from '@openzeppelin/token/ERC721/IERC721.sol';
import {ReentrancyGuard} from '@openzeppelin/utils/ReentrancyGuard.sol';
import {mulDiv} from '@prb/math/src/Common.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);
  event AntCreated();
  event AntSold();

  function buyEggs(uint256) external payable;

  error InsufficientEggs();
  error FailedToBurnEgg();
  error WrongEtherSent();
  error NoZeroAddress();
  error AlreadyExists();
  error Unauthorized();
  error RefundFailed();
  error MintFailed();
}

contract CryptoAnts is ERC721, ICryptoAnts, Ownable, ReentrancyGuard {
  IEgg public immutable EGGS;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  mapping(uint256 => address) public antToOwner;
  uint256[] public allAntsIds;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') Ownable(msg.sender) {
    EGGS = IEgg(_eggs);
  }

  function setEggPrice(uint256 _price) external onlyOwner {
    eggPrice = _price;
  }

  function buyEggs(uint256 _amount) external payable override nonReentrant {
    // Use PRB-Math mulDiv for safe multiplication: totalCost = (_amount * eggPrice) / 1
    uint256 totalCost = mulDiv(_amount, eggPrice, 1);
    if (msg.value < totalCost) revert WrongEtherSent();

    try EGGS.mint(msg.sender, _amount) {}
    catch (bytes memory err) {
      // propagate the error pattern
      assembly {
        let ptr := add(err, 0x20)
        let len := mload(ptr)
        revert(ptr, len)
      }
    }

    // Refund excess ether
    uint256 refund = msg.value - totalCost;
    if (refund > 0) {
      (bool success, bytes memory data) = msg.sender.call{value: refund}('');
      if (!success) {
        // propagate the error pattern
        assembly {
          let ptr := add(data, 0x20)
          let len := mload(ptr)
          revert(ptr, len)
        }
      }
    }

    emit EggsBought(msg.sender, _amount);
  }

  function createAnt() external {
    if (EGGS.balanceOf(msg.sender) < 1) revert InsufficientEggs();

    // Burn 1 egg by transferring it to this contract
    try EGGS.transferFrom(msg.sender, address(this), 1) {}
    catch (bytes memory err) {
      // propagate the error pattern
      assembly {
        let ptr := add(err, 0x20)
        let len := mload(ptr)
        revert(ptr, len)
      }
    }

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
    if (antToOwner[_antId] != msg.sender) revert Unauthorized();

    (bool isok, bytes memory data) = msg.sender.call{value: 0.004 ether}('');
    if (isok) {
      assembly {
        let ptr := add(data, 0x20)
        let len := mload(ptr)
        revert(ptr, len)
      }
    }

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
