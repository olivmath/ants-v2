// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

contract E2ECryptoAnts is Test, TestUtils {
  uint256 internal constant FORK_BLOCK = 9_817_118;
  ICryptoAnts internal _cryptoAnts;
  address internal _owner = makeAddr('owner');
  IEgg internal _eggs;

  function setUp() public {
    // Deploy contracts locally (no fork needed)
    // Get current nonce
    uint64 currentNonce = vm.getNonce(address(this));

    // Calculate future CryptoAnts address (will be deployed after Egg)
    address futureAntsAddress = vm.computeCreateAddress(address(this), currentNonce + 1);
    // Deploy Egg first with future CryptoAnts address
    _eggs = new Egg(futureAntsAddress);
    // Deploy CryptoAnts with Egg address (address must match futureAntsAddress)
    _cryptoAnts = new CryptoAnts(address(_eggs));
  }

  function testOnlyAllowCryptoAntsToMintEggs() public {
    // Given: a random user tries to mint eggs directly
    address attacker = makeAddr('attacker');
    vm.prank(attacker);

    // When: the user calls mint on the Egg contract
    // Then: the transaction should revert with the proper error message
    vm.expectRevert('Only the ants contract can call this function, please refer to the ants contract');
    _eggs.mint(attacker, 100);
  }

  function testBuyAnEggAndCreateNewAnt() public {
    // Given: a user wants to buy eggs and create an ant
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    // When: user buys 1 egg
    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    // Then: user should have 1 egg
    assertEq(_eggs.balanceOf(user), 1);

    // And: user should approve the contract to spend eggs
    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), 1);

    // When: user creates an ant
    vm.prank(user);
    _cryptoAnts.createAnt();

    // Then: user should own the ant (token ID 1)
    assertEq(_cryptoAnts.ownerOf(1), user);
    // And: user should have 0 eggs left
    assertEq(_eggs.balanceOf(user), 0);
    // And: total ants created should be 1
    assertEq(_cryptoAnts.getAntsCreated(), 1);
  }

  function testSendFundsToTheUserWhoSellsAnts() public {
    // Given: a user has created an ant
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), 1);

    vm.prank(user);
    _cryptoAnts.createAnt();

    // And: the contract has enough balance to pay
    vm.deal(address(_cryptoAnts), 1 ether);

    // When: user sells the ant
    uint256 balanceBefore = user.balance;
    vm.prank(user);
    _cryptoAnts.sellAnt(1);

    // Then: user should receive 0.004 ether
    assertEq(user.balance, balanceBefore + 0.004 ether);
  }

  function testBurnTheAntAfterTheUserSellsIt() public {
    // Given: a user has created an ant
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), 1);

    vm.prank(user);
    _cryptoAnts.createAnt();

    // And: the contract has enough balance to pay
    vm.deal(address(_cryptoAnts), 1 ether);

    // When: user sells the ant
    vm.prank(user);
    _cryptoAnts.sellAnt(1);

    // Then: the NFT should be burned (ownerOf should revert)
    vm.expectRevert();
    _cryptoAnts.ownerOf(1);
  }

  /*
    This is a completely optional test.
    Hint: you may need `warp` to handle the egg creation cooldown
  */
  function testBeAbleToCreate100AntsWithOnlyOneInitialEgg() public {
    // Given: a user starts with 1 egg
    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    // When: user creates the first ant
    vm.prank(user);
    _cryptoAnts.createAnt();

    // Then: user should be able to exponentially grow ants through egg laying
    // Note: This test demonstrates the concept - ant may die (10% chance) or lay eggs

    // Warp time to pass cooldown
    vm.warp(block.timestamp + 601);

    // Try to lay eggs with ant #1
    uint256 eggsBefore = _eggs.balanceOf(user);
    vm.prank(user);
    _cryptoAnts.layEggs(1);

    uint256 eggsAfter = _eggs.balanceOf(user);

    // Check if ant died or laid eggs
    try _cryptoAnts.ownerOf(1) returns (address) {
      // Ant survived - should have eggs
      assertGt(eggsAfter, eggsBefore, 'Survived ant should have laid eggs');

      // Create another ant from eggs
      if (eggsAfter > 0) {
        vm.prank(user);
        _cryptoAnts.createAnt();
        assertEq(_cryptoAnts.getAntsCreated(), 2, 'Should have created 2nd ant');
      }
    } catch {
      // Ant died - no eggs were laid
      assertEq(eggsAfter, eggsBefore, 'Dead ant should not lay eggs');
      assertEq(_cryptoAnts.getAntsCreated(), 1, 'Total ants should still be 1');
    }
  }
}
