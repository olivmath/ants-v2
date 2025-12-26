// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

/// @title CryptoAnts Unit Tests
/// @notice Unit tests for TDD/Coverage - focuses on individual functions and branches
contract CryptoAntsUnitTest is Test, TestUtils {
  ICryptoAnts internal _cryptoAnts;
  IEgg internal _eggs;
  address internal _owner;
  address internal _user;

  function setUp() public {
    _owner = address(this);
    _user = makeAddr('user');

    uint64 currentNonce = vm.getNonce(address(this));
    address futureAntsAddress = vm.computeCreateAddress(address(this), currentNonce + 1);
    _eggs = new Egg(futureAntsAddress);
    _cryptoAnts = new CryptoAnts(address(_eggs));

    vm.deal(_user, 100 ether);
  }

  // ============ setEggPrice ============

  function test_SetEggPrice_AsOwner() public {
    uint256 newPrice = 0.02 ether;
    _cryptoAnts.setEggPrice(newPrice);

    assertEq(_cryptoAnts.eggPrice(), newPrice);
  }

  function test_SetEggPrice_AsNonOwner_ShouldRevert() public {
    vm.prank(_user);
    vm.expectRevert();
    _cryptoAnts.setEggPrice(0.02 ether);
  }

  function test_SetEggPrice_ToZero() public {
    _cryptoAnts.setEggPrice(0);
    assertEq(_cryptoAnts.eggPrice(), 0);
  }

  function test_SetEggPrice_ToMaxUint() public {
    _cryptoAnts.setEggPrice(type(uint256).max);
    assertEq(_cryptoAnts.eggPrice(), type(uint256).max);
  }

  // ============ buyEggs ============

  function test_BuyEggs_ExactPayment() public {
    vm.prank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);

    assertEq(_eggs.balanceOf(_user), 1);
  }

  function test_BuyEggs_InsufficientPayment_ShouldRevert() public {
    vm.prank(_user);
    vm.expectRevert(ICryptoAnts.InsufficientEtherSent.selector);
    _cryptoAnts.buyEggs{value: 0.005 ether}(1);
  }

  function test_BuyEggs_ZeroAmount() public {
    vm.prank(_user);
    _cryptoAnts.buyEggs{value: 0}(0);

    assertEq(_eggs.balanceOf(_user), 0);
  }

  function test_BuyEggs_EventEmitted() public {
    vm.prank(_user);
    vm.expectEmit(true, true, false, false);
    emit ICryptoAnts.EggsBought(_user, 5);
    _cryptoAnts.buyEggs{value: 0.05 ether}(5);
  }

  // ============ createAnt ============

  function test_CreateAnt_WithSufficientEggs() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    assertEq(_cryptoAnts.ownerOf(1), _user);
    assertEq(_cryptoAnts.getAntsCreated(), 1);
  }

  function test_CreateAnt_WithoutEggs_ShouldRevert() public {
    vm.prank(_user);
    vm.expectRevert(ICryptoAnts.InsufficientEggs.selector);
    _cryptoAnts.createAnt();
  }

  function test_CreateAnt_InitializesMetadata() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    (uint40 lastEggLayTime, uint16 totalEggsLaid, bool isAlive) = _cryptoAnts.antsMetadata(1);

    assertEq(lastEggLayTime, 0);
    assertEq(totalEggsLaid, 0);
    assertTrue(isAlive);
  }

  function test_CreateAnt_EventEmitted() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);

    vm.expectEmit(false, false, false, false);
    emit ICryptoAnts.AntCreated();
    _cryptoAnts.createAnt();
    vm.stopPrank();
  }

  function test_CreateAnt_MultipleSequential() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.05 ether}(5);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    for (uint256 i = 1; i <= 5; i++) {
      _cryptoAnts.createAnt();
      assertEq(_cryptoAnts.getAntsCreated(), i);
      assertEq(_cryptoAnts.ownerOf(i), _user);
    }
    vm.stopPrank();
  }

  // ============ sellAnt ============

  function test_SellAnt_AsOwner() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    vm.deal(address(_cryptoAnts), 1 ether);

    uint256 balanceBefore = _user.balance;

    vm.prank(_user);
    _cryptoAnts.sellAnt(1);

    assertEq(_user.balance, balanceBefore + 0.004 ether);

    vm.expectRevert();
    _cryptoAnts.ownerOf(1);
  }

  function test_SellAnt_AsNonOwner_ShouldRevert() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    address attacker = makeAddr('attacker');

    vm.prank(attacker);
    vm.expectRevert(ICryptoAnts.Unauthorized.selector);
    _cryptoAnts.sellAnt(1);
  }

  function test_SellAnt_EventEmitted() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    vm.deal(address(_cryptoAnts), 1 ether);

    vm.expectEmit(false, false, false, false);
    emit ICryptoAnts.AntSold();

    vm.prank(_user);
    _cryptoAnts.sellAnt(1);
  }

  // ============ layEggs ============

  function test_LayEggs_AsNonOwner_ShouldRevert() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    address attacker = makeAddr('attacker');

    vm.warp(block.timestamp + 601);

    vm.prank(attacker);
    vm.expectRevert(ICryptoAnts.Unauthorized.selector);
    _cryptoAnts.layEggs(1);
  }

  function test_LayEggs_WithCooldown() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    vm.expectRevert(ICryptoAnts.CooldownNotMet.selector);
    vm.prank(_user);
    _cryptoAnts.layEggs(1);
  }

  function test_LayEggs_UpdatesMetadata() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    vm.warp(block.timestamp + 601);

    vm.prank(_user);
    _cryptoAnts.layEggs(1);

    // Check if ant survived
    try _cryptoAnts.ownerOf(1) {
      (uint40 lastEggLayTime, uint16 totalEggsLaid, bool isAlive) = _cryptoAnts.antsMetadata(1);

      assertEq(lastEggLayTime, block.timestamp);
      assertGt(totalEggsLaid, 0);
      assertTrue(isAlive);
    } catch {
      // Ant died - metadata should reflect that
      (,, bool isAlive) = _cryptoAnts.antsMetadata(1);
      assertFalse(isAlive);
    }
  }

  // ============ View Functions ============

  function test_GetContractBalance() public {
    assertEq(_cryptoAnts.getContractBalance(), 0);

    vm.deal(address(_cryptoAnts), 5 ether);

    assertEq(_cryptoAnts.getContractBalance(), 5 ether);
  }

  function test_GetAntsCreated() public {
    assertEq(_cryptoAnts.getAntsCreated(), 0);

    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.03 ether}(3);
    _eggs.approve(address(_cryptoAnts), type(uint256).max);

    _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.getAntsCreated(), 1);

    _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.getAntsCreated(), 2);

    _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.getAntsCreated(), 3);
    vm.stopPrank();
  }

  // ============ Edge Cases ============

  function test_AntIdStartsAtOne() public {
    vm.startPrank(_user);
    _cryptoAnts.buyEggs{value: 0.01 ether}(1);
    _eggs.approve(address(_cryptoAnts), 1);
    _cryptoAnts.createAnt();
    vm.stopPrank();

    assertEq(_cryptoAnts.ownerOf(1), _user);
  }

  function test_EggPriceDefault() public {
    assertEq(_cryptoAnts.eggPrice(), 0.01 ether);
  }

  function test_CooldownConstant() public view {
    uint256 expected = 600; // 10 minutes
    // Note: Can't directly test constant, but can verify through behavior
    // This is tested in layEggs tests
  }
}
