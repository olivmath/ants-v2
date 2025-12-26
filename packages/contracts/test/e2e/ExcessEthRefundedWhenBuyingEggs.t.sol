// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'src/CryptoAnts.sol';
import {Egg, IEgg} from 'src/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';

contract ExcessEthRefundedWhenBuyingEggsTest is Test, TestUtils {
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

  function testExcessEthRefundedWhenBuyingEggs() public {
    // Given: egg price is 0.01 ETH and user wants to buy 5 eggs (cost = 0.05 ETH)
    address user = makeAddr('user');
    uint256 initialBalance = 1 ether;
    vm.deal(user, initialBalance);

    uint256 eggsToBuy = 5;
    uint256 costPerEgg = 0.01 ether;
    uint256 totalCost = eggsToBuy * costPerEgg; // 0.05 ETH
    uint256 payment = 0.1 ether; // User overpays

    // When: user sends 0.1 ETH to buyEggs(5)
    vm.prank(user);
    _cryptoAnts.buyEggs{value: payment}(eggsToBuy);

    // Then: 5 eggs should be minted to the user
    assertEq(_eggs.balanceOf(user), eggsToBuy, 'Should receive 5 eggs');

    // And: 0.05 ETH should be refunded to the user
    // And: user's final balance should be initial - 0.05 ETH
    uint256 finalBalance = user.balance;
    uint256 expectedFinalBalance = initialBalance - totalCost;

    assertEq(finalBalance, expectedFinalBalance, 'User should be refunded excess ETH');
    assertEq(finalBalance, initialBalance - totalCost, 'User paid only for eggs');
  }
}
