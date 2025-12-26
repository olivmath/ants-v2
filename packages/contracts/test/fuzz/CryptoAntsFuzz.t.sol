// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

contract CryptoAntsFuzzTest is Test, TestUtils {
  ICryptoAnts internal _cryptoAnts;
  IEgg internal _eggs;

  function setUp() public {
    uint64 currentNonce = vm.getNonce(address(this));
    address futureAntsAddress = vm.computeCreateAddress(address(this), currentNonce + 1);
    _eggs = new Egg(futureAntsAddress);
    _cryptoAnts = new CryptoAnts(address(_eggs));
  }

  /// @notice Fuzz test: buying eggs with random amounts and payments
  function testFuzz_BuyEggs(uint256 amount, uint256 payment) public {
    // Bound inputs to reasonable ranges
    amount = bound(amount, 1, 1000); // 1 to 1000 eggs
    payment = bound(payment, 0.01 ether, 100 ether); // 0.01 to 100 ETH

    address user = makeAddr('user');
    vm.deal(user, payment);

    uint256 eggPrice = 0.01 ether;
    uint256 totalCost = amount * eggPrice;

    if (payment < totalCost) {
      // Should revert with InsufficientEtherSent
      vm.expectRevert(ICryptoAnts.InsufficientEtherSent.selector);
      vm.prank(user);
      _cryptoAnts.buyEggs{value: payment}(amount);
    } else {
      // Should succeed
      uint256 balanceBefore = user.balance;

      vm.prank(user);
      _cryptoAnts.buyEggs{value: payment}(amount);

      // Verify eggs minted
      assertEq(_eggs.balanceOf(user), amount, 'Should receive correct amount of eggs');

      // Verify correct refund
      assertEq(user.balance, balanceBefore - totalCost, 'Should be refunded excess ETH');
    }
  }

  /// @notice Fuzz test: egg price setting
  function testFuzz_SetEggPrice(uint256 newPrice) public {
    // Bound to reasonable range (0 to 10 ETH)
    newPrice = bound(newPrice, 0, 10 ether);

    _cryptoAnts.setEggPrice(newPrice);

    assertEq(_cryptoAnts.eggPrice(), newPrice, 'Price should be updated');
  }

  /// @notice Fuzz test: egg distribution range
  function testFuzz_EggDistributionRange(
    uint256 /* seed */
  ) public {
    // Test that _getNormalDistributedEggs always returns 0-20
    // We can't call private function directly, so we test via layEggs

    address user = makeAddr('user');
    vm.deal(user, 1 ether);

    // Setup: create ant
    vm.prank(user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    vm.prank(user);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    vm.prank(user);
    _cryptoAnts.createAnt();

    // Warp time past cooldown
    vm.warp(block.timestamp + 601);

    // Lay eggs
    uint256 eggsBefore = _eggs.balanceOf(user);

    vm.prank(user);
    _cryptoAnts.layEggs(1);

    uint256 eggsAfter = _eggs.balanceOf(user);

    // Check if ant survived
    try _cryptoAnts.ownerOf(1) {
      // Ant survived - should have laid eggs in range 0-20
      uint256 eggsLaid = eggsAfter - eggsBefore;
      assertLe(eggsLaid, 20, 'Should not lay more than 20 eggs');
    } catch {
      // Ant died - should have 0 eggs laid
      assertEq(eggsAfter, eggsBefore, 'Dead ant should not lay eggs');
    }
  }

  /// @notice Fuzz test: ant creation with varying egg balances
  function testFuzz_CreateAntWithVaryingEggs(uint256 eggCount) public {
    eggCount = bound(eggCount, 0, 100);

    address user = makeAddr('user');
    vm.deal(user, 100 ether);

    if (eggCount > 0) {
      // Buy eggs
      vm.prank(user);
      _cryptoAnts.buyEggs{value: eggCount * 0.01 ether}(eggCount);

      vm.prank(user);
      _eggs.approve(address(_cryptoAnts), type(uint256).max);

      // Create ants (1 egg per ant)
      for (uint256 i = 0; i < eggCount; i++) {
        vm.prank(user);
        _cryptoAnts.createAnt();

        // Verify ant created
        assertEq(_cryptoAnts.getAntsCreated(), i + 1, 'Ant should be created');
        assertEq(_cryptoAnts.ownerOf(i + 1), user, 'User should own ant');
      }

      // Verify all eggs consumed
      assertEq(_eggs.balanceOf(user), 0, 'All eggs should be consumed');
    } else {
      // Should revert with InsufficientEggs
      vm.expectRevert(ICryptoAnts.InsufficientEggs.selector);
      vm.prank(user);
      _cryptoAnts.createAnt();
    }
  }

  /// @notice Fuzz test: randomness produces varied results
  function testFuzz_RandomnessVariation(uint256 iterations) public {
    iterations = bound(iterations, 10, 50);

    address user = makeAddr('user');
    vm.deal(user, 100 ether);

    // Track egg counts in array (max 21 possible values: 0-20)
    uint256[] memory eggCounts = new uint256[](21);
    uint256 uniqueCountsFound = 0;

    for (uint256 i = 0; i < iterations; i++) {
      // Create ant
      vm.prank(user);
      _cryptoAnts.buyEggs{value: 0.01 ether}(1);

      vm.prank(user);
      _eggs.approve(address(_cryptoAnts), type(uint256).max);

      vm.prank(user);
      _cryptoAnts.createAnt();

      uint256 antId = _cryptoAnts.getAntsCreated();

      // Warp time + vary timestamp for different randomness
      vm.warp(block.timestamp + 601 + i);

      uint256 eggsBefore = _eggs.balanceOf(user);

      vm.prank(user);
      _cryptoAnts.layEggs(antId);

      uint256 eggsAfter = _eggs.balanceOf(user);
      uint256 eggsLaid = eggsAfter - eggsBefore;

      // Track unique counts
      if (eggCounts[eggsLaid] == 0) {
        uniqueCountsFound++;
      }
      eggCounts[eggsLaid]++;
    }

    // Should have at least 3 different egg counts (proves randomness)
    assertGe(uniqueCountsFound, 3, 'Randomness should produce varied results');
  }
}
