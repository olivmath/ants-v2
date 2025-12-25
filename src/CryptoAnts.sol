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
  event EggsLaid(uint256 indexed antId, address indexed owner, uint256 eggCount);
  event AntDied(uint256 indexed antId, address indexed owner);

  function buyEggs(uint256) external payable;
  function layEggs(uint256 _antId) external;

  error InsufficientEggs();
  error FailedToBurnEgg();
  error WrongEtherSent();
  error NoZeroAddress();
  error AlreadyExists();
  error Unauthorized();
  error RefundFailed();
  error MintFailed();
  error CooldownNotMet();
  error AntIsDead();
}

contract CryptoAnts is ERC721, ICryptoAnts, Ownable, ReentrancyGuard {
  struct Ant {
    uint40 lastEggLayTime; // Timestamp of last egg laying
    uint16 totalEggsLaid; // Lifetime egg count
    bool isAlive; // Life status
  }

  IEgg public immutable EGGS;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  mapping(uint256 => address) public antToOwner;
  mapping(uint256 => Ant) public ants;
  uint256[] public allAntsIds;
  uint256 public constant EGG_LAY_COOLDOWN = 600; // 10 minutes in seconds

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
    // using: [ ++i ] to save gas [gas-increment-by-one]
    for (uint256 i = 0; i < allAntsIds.length; ++i) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);

    // Initialize ant data
    ants[_antId] = Ant({
      lastEggLayTime: uint40(block.timestamp), // Cooldown starts now
      totalEggsLaid: 0,
      isAlive: true
    });

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

  /// @notice Allows an ant to lay eggs with cooldown and death mechanics
  /// @param _antId The token ID of the ant laying eggs
  function layEggs(uint256 _antId) external override nonReentrant {
    // 1. Validate ownership
    if (antToOwner[_antId] != msg.sender) revert Unauthorized();

    // 2. Load ant data (single SLOAD)
    Ant storage ant = ants[_antId];

    // 3. Initialize old ant (backward compatibility)
    if (ant.lastEggLayTime == 0 && !ant.isAlive) {
      ant.isAlive = true;
      ant.lastEggLayTime = uint40(block.timestamp);
    }

    // 4. Check if alive
    if (!ant.isAlive) revert AntIsDead();

    // 5. Validate cooldown
    if (block.timestamp < ant.lastEggLayTime + EGG_LAY_COOLDOWN) {
      revert CooldownNotMet();
    }

    // 6. Generate randomness
    uint256 randomSeed = _generateRandomNumber(_antId, ant.totalEggsLaid);

    // 7. Check death (10% = 0-9 out of 100)
    bool died = (randomSeed % 100) < 10;

    if (died) {
      ant.isAlive = false;
      _burn(_antId);
      emit AntDied(_antId, msg.sender);
      return; // No eggs when dying
    }

    // 8. Calculate egg count
    uint256 eggCount = _getNormalDistributedEggs(randomSeed);

    // 9. Update state
    ant.lastEggLayTime = uint40(block.timestamp);
    ant.totalEggsLaid += uint16(eggCount);

    // 10. Mint eggs
    if (eggCount > 0) {
      try EGGS.mint(msg.sender, eggCount) {}
      catch (bytes memory err) {
        assembly {
          let ptr := add(err, 0x20)
          let len := mload(ptr)
          revert(ptr, len)
        }
      }
    }

    emit EggsLaid(_antId, msg.sender, eggCount);
  }

  /// @notice Generates pseudo-random number using block data
  /// @dev NOT cryptographically secure - acceptable for game mechanics
  /// @param _antId Ant token ID for entropy
  /// @param _nonce Additional entropy from caller
  /// @return Random uint256
  function _generateRandomNumber(uint256 _antId, uint256 _nonce) private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, _antId, _nonce, msg.sender)));
  }

  /// @notice Generates normally distributed egg count (0-20 range, mean ~10)
  /// @dev Uses triangle distribution (average of 2 uniform random variables)
  /// @param _randomSeed Random seed from _generateRandomNumber
  /// @return eggCount Number of eggs (0-20, favoring center)
  function _getNormalDistributedEggs(uint256 _randomSeed) private pure returns (uint256) {
    uint256 rand1 = _randomSeed % 21; // 0-20
    uint256 rand2 = (_randomSeed >> 128) % 21; // 0-20
    return (rand1 + rand2) / 2; // Average: 0-20, peaks at 10
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }
}
