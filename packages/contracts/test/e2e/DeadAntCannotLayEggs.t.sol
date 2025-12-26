// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

contract DeadAntCannotLayEggsTest is Test, TestUtils {
  uint256 internal constant FORK_BLOCK = 9_817_118;
  ICryptoAnts internal _cryptoAnts;
  address internal _owner = makeAddr('owner');
  IEgg internal _eggs;

  function setUp() public {
    // Deploy contracts locally (no fork needed)
    uint64 currentNonce = vm.getNonce(address(this));
    address futureAntsAddress = vm.computeCreateAddress(address(this), currentNonce + 1);
    _eggs = new Egg(futureAntsAddress);
    _cryptoAnts = new CryptoAnts(address(_eggs), 'ipfs://bafkreic7mcysfc7eqlri2pjkfupkri7xk47c25hbwp4sm34owe3hudkkzm/');
  }

  function testDeadAntCannotLayEggs() public {
    // Given: a user buys an egg and creates an ant
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    vm.prank(user);
    _cryptoAnts.createAnt();

    // And: we try to lay eggs until the ant dies (10% chance each try)
    // Max 100 attempts (probability of not dying after 100 tries = 0.9^100 ≈ 0.0027%)
    bool antDied = false;
    for (uint256 i = 0; i < 100; i++) {
      vm.warp(block.timestamp + 601);

      vm.prank(user);
      _cryptoAnts.layEggs(1);

      // Check if ant died
      try _cryptoAnts.ownerOf(1) {
        // Ant still alive, continue
        continue;
      } catch {
        // Ant died (NFT burned)
        antDied = true;
        break;
      }
    }

    // Ensure ant died
    require(antDied, 'Ant should have died eventually');

    // When: user tries to lay eggs with the dead ant (already burned)
    // Then: the transaction should revert (ownerOf will revert since NFT is burned)
    vm.expectRevert();
    vm.prank(user);
    _cryptoAnts.layEggs(1);
  }
}
