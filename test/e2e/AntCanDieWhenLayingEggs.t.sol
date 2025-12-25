// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

contract AntCanDieWhenLayingEggsTest is Test, TestUtils {
  uint256 internal constant FORK_BLOCK = 9_817_118;
  ICryptoAnts internal _cryptoAnts;
  address internal _owner = makeAddr('owner');
  IEgg internal _eggs;

  function setUp() public {
    // Deploy contracts locally (no fork needed)
    uint64 currentNonce = vm.getNonce(address(this));
    address futureAntsAddress = vm.computeCreateAddress(address(this), currentNonce + 1);
    _eggs = new Egg(futureAntsAddress);
    _cryptoAnts = new CryptoAnts(address(_eggs));
  }

  function testAntCanDieWhenLayingEggs() public {
    // Given: a user has a live ant ready to lay eggs
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    vm.prank(user);
    _cryptoAnts.createAnt();

    // When: layEggs is called repeatedly until death occurs (10% chance per call)
    bool antDied = false;
    for (uint256 i = 0; i < 100; i++) {
      vm.warp(block.timestamp + 601);

      uint256 eggsBefore = _eggs.balanceOf(user);

      vm.prank(user);
      _cryptoAnts.layEggs(1);

      uint256 eggsAfter = _eggs.balanceOf(user);

      // Check if ant died
      try _cryptoAnts.ownerOf(1) {
        // Ant still alive - should have received eggs
        assertGt(eggsAfter, eggsBefore, 'Alive ant should lay eggs');
        continue;
      } catch {
        // Then: ant died - NFT should be burned
        antDied = true;

        // And: no eggs should be minted when dying
        assertEq(eggsAfter, eggsBefore, 'Dead ant should not lay eggs');

        // And: ant should be marked as dead
        (,, bool isAlive) = _cryptoAnts.antsMetadata(1);
        assertFalse(isAlive, 'Ant should be marked as dead');

        break;
      }
    }

    // Verify ant eventually died
    assertTrue(antDied, 'Ant should die eventually (10% chance per attempt)');
  }
}
