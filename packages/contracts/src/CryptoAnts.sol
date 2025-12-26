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
import {Base64} from '@openzeppelin/utils/Base64.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
  function burnFrom(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);
  event AntCreated();
  event AntSold();
  event EggsLaid(uint256 indexed antId, address indexed owner, uint256 eggCount);
  event AntDied(uint256 indexed antId, address indexed owner);

  function antsMetadata(uint256) external view returns (uint40, uint16, uint24, uint24, bool);
  function getContractBalance() external view returns (uint256);
  function getAntsCreated() external view returns (uint256);
  function eggPrice() external view returns (uint256);

  function setEggPrice(uint256 _price) external;
  function buyEggs(uint256) external payable;
  function sellAnt(uint256 _antId) external;
  function layEggs(uint256 _antId) external;
  function createAnt() external;

  error InsufficientEggs();
  error FailedToBurnEgg();
  error InsufficientEtherSent();
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
    uint24 color; // RGB color (0xRRGGBB) - ant color, generated randomly at creation
    uint24 eggColor; // RGB color (0xRRGGBB) - egg color, generated randomly at creation
    bool isAlive; // Life status
  }

  IEgg public immutable EGGS;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  uint256 public constant EGG_LAY_COOLDOWN = 600; // 10 minutes in seconds

  // IPFS base URI for SVG template
  string public baseTokenURI;

  mapping(uint256 => Ant) public antsMetadata;

  constructor(address _eggs, string memory _baseTokenURI) ERC721('Crypto Ants', 'ANTS') Ownable(msg.sender) {
    EGGS = IEgg(_eggs);
    baseTokenURI = _baseTokenURI;
  }

  /// @notice Updates the base token URI for metadata
  /// @param _baseTokenURI New base URI (e.g., IPFS gateway URL)
  function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
    baseTokenURI = _baseTokenURI;
  }

  function setEggPrice(uint256 _price) external onlyOwner {
    eggPrice = _price;
  }

  function buyEggs(uint256 _amount) external payable override nonReentrant {
    // (safe in Solidity 0.8+)
    uint256 totalCost = _amount * eggPrice;
    if (msg.value < totalCost) revert InsufficientEtherSent();
    uint256 diff = msg.value - totalCost;

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
    if (diff > 0) {
      (bool success, bytes memory data) = msg.sender.call{value: diff}('');
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
    try EGGS.burnFrom(msg.sender, 1) {}
    catch (bytes memory err) {
      // propagate the error pattern
      assembly {
        let ptr := add(err, 0x20)
        let len := mload(ptr)
        revert(ptr, len)
      }
    }

    ++antsCreated;
    _mint(msg.sender, antsCreated);

    // Generate random colors (RGB: 0xRRGGBB)
    uint256 randomSeed = _generateRandomNumber(antsCreated, block.timestamp);
    uint24 antColor = uint24(randomSeed & 0xFFFFFF);
    uint24 eggColor = uint24((randomSeed >> 24) & 0xFFFFFF);

    antsMetadata[antsCreated] = Ant({
      lastEggLayTime: 0,
      totalEggsLaid: 0,
      color: antColor,
      eggColor: eggColor,
      isAlive: true
    });

    emit AntCreated();
  }

  function sellAnt(uint256 _antId) external {
    if (ownerOf(_antId) != msg.sender) revert Unauthorized();
    if (!antsMetadata[_antId].isAlive) revert AntIsDead();

    (bool isok, bytes memory data) = msg.sender.call{value: 0.004 ether}('');
    if (!isok) {
      assembly {
        let ptr := add(data, 0x20)
        let len := mload(ptr)
        revert(ptr, len)
      }
    }

    _burn(_antId);
    antsMetadata[_antId].isAlive = false;

    emit AntSold();
  }

  function layEggs(uint256 _antId) external override nonReentrant {
    if (ownerOf(_antId) != msg.sender) revert Unauthorized();
    Ant storage ant = antsMetadata[_antId];
    if (!ant.isAlive) revert AntIsDead();
    if (block.timestamp < ant.lastEggLayTime + EGG_LAY_COOLDOWN) revert CooldownNotMet();

    uint256 randomSeed = _generateRandomNumber(_antId, ant.totalEggsLaid);

    bool died = (randomSeed % 100) < 10;

    if (died) {
      ant.isAlive = false;
      _burn(_antId);
      emit AntDied(_antId, msg.sender);
      return;
    }

    uint256 eggCount = _getNormalDistributedEggs(randomSeed);

    ant.lastEggLayTime = uint40(block.timestamp);
    // casting to 'uint16' is safe because _getNormalDistributedEggs returns 0-20 (max 20 << 65535)
    // forge-lint: disable-next-line(unsafe-typecast)
    ant.totalEggsLaid += uint16(eggCount);

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

  /// @notice Returns the metadata URI for a given token
  /// @dev Returns JSON metadata with IPFS reference for frontend rendering
  /// @param tokenId The token ID to get metadata for
  /// @return The base64-encoded JSON metadata URI
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_ownerOf(tokenId) != address(0), 'Token does not exist');

    Ant memory ant = antsMetadata[tokenId];
    uint24 displayAntColor = _getDisplayAntColor(ant);

    // Build complete JSON metadata with IPFS reference
    string memory json = _buildMetadataJSON(tokenId, ant, displayAntColor);

    // Encode to base64 and return data URI
    return string(abi.encodePacked('data:application/json;base64,', Base64.encode(bytes(json))));
  }

  /// @notice Gets the display color for an ant based on its state
  /// @param ant The ant struct
  /// @return The display color (red if dead, green if no eggs, original otherwise)
  function _getDisplayAntColor(Ant memory ant) private pure returns (uint24) {
    if (!ant.isAlive) {
      return 0xFF0000; // Red for dead ants
    } else if (ant.totalEggsLaid == 0) {
      return 0x00FF00; // Green for ants that haven't laid eggs yet
    } else {
      return ant.color;
    }
  }

  /// @notice Builds the complete metadata JSON
  /// @param tokenId The token ID
  /// @param ant The ant struct
  /// @param displayAntColor The display color for the ant
  /// @return The complete JSON metadata string
  function _buildMetadataJSON(
    uint256 tokenId,
    Ant memory ant,
    uint24 displayAntColor
  ) private view returns (string memory) {
    string memory attributes = _buildAttributes(ant, displayAntColor);

    return
      string(
        abi.encodePacked(
          '{',
          '"name":"Crypto Ant #',
          Strings.toString(tokenId),
          '",',
          '"description":"A dynamic breeding ant NFT. Total eggs: ',
          Strings.toString(ant.totalEggsLaid),
          '. Status: ',
          ant.isAlive ? 'Alive' : 'Dead',
          '.",',
          '"image":"',
          baseTokenURI,
          '",',
          '"attributes":',
          attributes,
          '}'
        )
      );
  }

  /// @notice Builds the attributes JSON array
  /// @param ant The ant struct
  /// @param displayAntColor The display color for the ant
  /// @return The attributes JSON array string
  function _buildAttributes(Ant memory ant, uint24 displayAntColor) private pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '[',
          '{"trait_type":"Total Eggs Laid","value":',
          Strings.toString(ant.totalEggsLaid),
          '},',
          '{"trait_type":"Status","value":"',
          ant.isAlive ? 'Alive' : 'Dead',
          '"},',
          '{"trait_type":"Ant Color","value":"#',
          _toHexString(displayAntColor),
          '"},',
          '{"trait_type":"Egg Color","value":"#',
          _toHexString(ant.eggColor),
          '"}',
          ']'
        )
      );
  }

  /// @notice Converts uint24 color to hex string (without 0x prefix)
  /// @param color The RGB color value (0xRRGGBB)
  /// @return Hex string representation (6 characters)
  function _toHexString(uint24 color) private pure returns (string memory) {
    bytes memory hexChars = '0123456789ABCDEF';
    bytes memory result = new bytes(6);

    for (uint256 i = 0; i < 3; i++) {
      uint8 byteValue = uint8((color >> (8 * (2 - i))) & 0xFF);
      result[i * 2] = hexChars[byteValue >> 4];
      result[i * 2 + 1] = hexChars[byteValue & 0x0F];
    }

    return string(result);
  }
}
