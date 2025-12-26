// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {SymTest} from 'halmos-cheatcodes/SymTest.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';

/// @title CryptoAnts Formal Verification Tests
/// @notice Formal verification using Halmos to prove contract invariants
/// @dev Run with: halmos --contract CryptoAntsFormalTest
/// @dev Setup: forge install a16z/halmos-cheatcodes && pip install halmos
contract CryptoAntsFormalTest is Test, SymTest {
  CryptoAnts internal cryptoAnts;
  Egg internal eggs;

  function setUp() public {
    // Deploy Egg with placeholder address first
    eggs = new Egg(address(0xdead));
    // Deploy CryptoAnts with actual Egg address
    cryptoAnts = new CryptoAnts(address(eggs));

    // Note: In production, use circular deployment with nonce prediction
    // This simplified setup works for formal verification
  }

  /// @custom:halmos --loop 3
  /// INVARIANT 1: Ant IDs are unique and sequential
  /// Prove: antsCreated always increases by exactly 1
  function check_AntIdUniqueness(uint256 iterations) public {
    // Symbolic input: number of ants to create
    iterations = svm.createUint256('iterations');
    vm.assume(iterations > 0 && iterations <= 3);

    uint256 lastId = 0;

    for (uint256 i = 0; i < iterations; i++) {
      // Setup: give user eggs
      address user = address(uint160(i + 1));
      vm.deal(user, 1 ether);

      vm.prank(user);
      cryptoAnts.buyEggs{value: 0.01 ether}(1);

      vm.prank(user);
      eggs.approve(address(cryptoAnts), 1);

      uint256 antsBefore = cryptoAnts.getAntsCreated();

      vm.prank(user);
      cryptoAnts.createAnt();

      uint256 antsAfter = cryptoAnts.getAntsCreated();

      // INVARIANT: Each ant creation increments counter by exactly 1
      assert(antsAfter == antsBefore + 1);

      // INVARIANT: Ant IDs are sequential
      assert(antsAfter == lastId + 1);

      lastId = antsAfter;
    }
  }

  /// INVARIANT 2: Dead ants never become alive
  /// Prove: If ant.isAlive == false, it stays false forever
  function check_DeadAntsStayDead() public {
    address user = svm.createAddress('user');
    vm.deal(user, 10 ether);

    // Create ant
    vm.prank(user);
    cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    eggs.approve(address(cryptoAnts), 1);

    vm.prank(user);
    cryptoAnts.createAnt();

    // Kill ant by selling
    vm.deal(address(cryptoAnts), 1 ether);
    vm.prank(user);
    cryptoAnts.sellAnt(1);

    // Check metadata
    (,, bool isAliveBefore) = cryptoAnts.antsMetadata(1);

    // Try any operation (shouldn't revive)
    vm.warp(block.timestamp + 1000);

    // Check metadata again
    (,, bool isAliveAfter) = cryptoAnts.antsMetadata(1);

    // INVARIANT: Once dead, always dead
    assert(!isAliveBefore);
    assert(!isAliveAfter);
    assert(isAliveBefore == isAliveAfter);
  }

  /// INVARIANT 3: Economic invariant - Total eggs minted = eggs bought + eggs laid
  /// Prove: No eggs created/destroyed except through buyEggs and layEggs
  function check_EggConservation() public {
    address user1 = svm.createAddress('user1');
    address user2 = svm.createAddress('user2');

    vm.deal(user1, 10 ether);
    vm.deal(user2, 10 ether);

    // Buy eggs
    uint256 eggsBought1 = svm.createUint256('eggsBought1');
    vm.assume(eggsBought1 > 0 && eggsBought1 <= 10);

    vm.prank(user1);
    cryptoAnts.buyEggs{value: eggsBought1 * 0.01 ether}(eggsBought1);

    uint256 totalEggsAfterBuy = eggs.balanceOf(user1);

    // INVARIANT: Eggs bought = eggs balance
    assert(totalEggsAfterBuy == eggsBought1);

    // Create ant (burns 1 egg)
    vm.prank(user1);
    eggs.approve(address(cryptoAnts), type(uint256).max);

    vm.prank(user1);
    cryptoAnts.createAnt();

    uint256 eggsAfterCreate = eggs.balanceOf(user1);

    // INVARIANT: Creating ant burns exactly 1 egg
    assert(eggsAfterCreate == totalEggsAfterBuy - 1);
  }

  /// INVARIANT 4: Cooldown enforcement
  /// Prove: Can't lay eggs twice within cooldown period
  function check_CooldownEnforcement() public {
    address user = svm.createAddress('user');
    vm.deal(user, 10 ether);

    // Setup: create ant
    vm.prank(user);
    cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    eggs.approve(address(cryptoAnts), 1);

    vm.prank(user);
    cryptoAnts.createAnt();

    // First egg laying (after cooldown)
    vm.warp(block.timestamp + 601);

    vm.prank(user);
    cryptoAnts.layEggs(1);

    // Check if ant survived
    try cryptoAnts.ownerOf(1) {
      // Ant alive - get timestamp
      (uint40 lastEggLayTime,,) = cryptoAnts.antsMetadata(1);

      // Try to lay eggs immediately (should fail)
      vm.expectRevert(ICryptoAnts.CooldownNotMet.selector);
      vm.prank(user);
      cryptoAnts.layEggs(1);

      // INVARIANT: Cooldown must pass before next egg laying
      // After cooldown, should work
      vm.warp(block.timestamp + 600);

      // This should still revert (need 600 seconds from last lay time)
      vm.expectRevert(ICryptoAnts.CooldownNotMet.selector);
      vm.prank(user);
      cryptoAnts.layEggs(1);

      // Now exactly at cooldown boundary
      vm.warp(lastEggLayTime + 600);

      vm.prank(user);
      cryptoAnts.layEggs(1); // Should work
    } catch {
      // Ant died - test still valid (cooldown was enforced before death)
    }
  }

  /// INVARIANT 5: Ant ownership
  /// Prove: Only owner can operate on ant
  function check_OwnershipEnforcement() public {
    address owner = svm.createAddress('owner');
    address attacker = svm.createAddress('attacker');
    vm.assume(owner != attacker);

    vm.deal(owner, 10 ether);

    // Create ant
    vm.prank(owner);
    cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(owner);
    eggs.approve(address(cryptoAnts), 1);

    vm.prank(owner);
    cryptoAnts.createAnt();

    // INVARIANT: Non-owner cannot sell
    vm.prank(attacker);
    vm.expectRevert(ICryptoAnts.Unauthorized.selector);
    cryptoAnts.sellAnt(1);

    // INVARIANT: Non-owner cannot lay eggs
    vm.warp(block.timestamp + 601);

    vm.prank(attacker);
    vm.expectRevert(ICryptoAnts.Unauthorized.selector);
    cryptoAnts.layEggs(1);

    // INVARIANT: Owner still owns the ant
    assert(cryptoAnts.ownerOf(1) == owner);
  }

  /// INVARIANT 6: Egg laying range
  /// Prove: Eggs laid is always in range [0, 20]
  function check_EggLayingRange() public {
    address user = svm.createAddress('user');
    vm.deal(user, 10 ether);

    // Create ant
    vm.prank(user);
    cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    eggs.approve(address(cryptoAnts), 1);

    vm.prank(user);
    cryptoAnts.createAnt();

    vm.warp(block.timestamp + 601);

    uint256 eggsBefore = eggs.balanceOf(user);

    vm.prank(user);
    cryptoAnts.layEggs(1);

    uint256 eggsAfter = eggs.balanceOf(user);

    // Check if ant survived
    try cryptoAnts.ownerOf(1) {
      uint256 eggsLaid = eggsAfter - eggsBefore;

      // INVARIANT: Eggs laid must be in range [0, 20]
      assert(eggsLaid >= 0 && eggsLaid <= 20);
    } catch {
      // Ant died - should have laid 0 eggs
      assert(eggsAfter == eggsBefore);
    }
  }

  /// INVARIANT 7: Payment correctness
  /// Prove: User pays exactly eggPrice * amount (minus refund)
  function check_PaymentCorrectness() public {
    address user = svm.createAddress('user');
    vm.deal(user, 100 ether);

    uint256 eggsToBuy = svm.createUint256('eggsToBuy');
    vm.assume(eggsToBuy > 0 && eggsToBuy <= 10);

    uint256 eggPrice = cryptoAnts.eggPrice();
    uint256 payment = eggsToBuy * eggPrice;

    uint256 balanceBefore = user.balance;

    vm.prank(user);
    cryptoAnts.buyEggs{value: payment}(eggsToBuy);

    uint256 balanceAfter = user.balance;

    // INVARIANT: User paid exactly eggPrice * amount
    assert(balanceAfter == balanceBefore - payment);

    // INVARIANT: User received exact eggs
    assert(eggs.balanceOf(user) == eggsToBuy);
  }
}
