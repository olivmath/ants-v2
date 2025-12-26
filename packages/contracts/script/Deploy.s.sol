// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';
import {CryptoAnts} from 'src/CryptoAnts.sol';
import {Egg} from 'src/Egg.sol';

/// @title Deploy Script
/// @notice Deploys CryptoAnts and Egg contracts with proper circular dependency handling
contract Deploy is Script {
  function run() external returns (CryptoAnts cryptoAnts, Egg eggs) {
    // Get deployer from environment or use default (Anvil account #0)
    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    console2.log('Deployer:', deployer);
    console2.log('Deployer balance:', deployer.balance);

    vm.startBroadcast();

    // Calculate future CryptoAnts address
    // Next deployment will be at nonce + 1 (Egg is nonce, CryptoAnts is nonce + 1)
    uint64 currentNonce = uint64(vm.getNonce(deployer));
    address futureCryptoAntsAddress = vm.computeCreateAddress(deployer, currentNonce + 1);

    console2.log('Current nonce:', currentNonce);
    console2.log('Future CryptoAnts address:', futureCryptoAntsAddress);

    // Deploy Egg with future CryptoAnts address
    eggs = new Egg(futureCryptoAntsAddress);
    console2.log('Egg deployed at:', address(eggs));

    // Deploy CryptoAnts with Egg address
    cryptoAnts = new CryptoAnts(address(eggs), 'ipfs://bafkreic7mcysfc7eqlri2pjkfupkri7xk47c25hbwp4sm34owe3hudkkzm/');
    console2.log('CryptoAnts deployed at:', address(cryptoAnts));

    // Verify circular dependency is correct
    require(address(cryptoAnts) == futureCryptoAntsAddress, 'CryptoAnts address mismatch');
    require(address(cryptoAnts.EGGS()) == address(eggs), 'Egg address mismatch');

    console2.log('\n=== Deployment Successful ===');
    console2.log('Egg:', address(eggs));
    console2.log('CryptoAnts:', address(cryptoAnts));
    console2.log('Egg Price:', cryptoAnts.eggPrice());

    vm.stopBroadcast();

    return (cryptoAnts, eggs);
  }
}
