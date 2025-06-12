// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../src/NumaFlashLender.sol";

contract Deploy is Script {
    // Numa address on sonic
    address constant NUMA_TOKEN = 0x925c5ed4ededfcaca82302e8a2e947b0d0e19cf3;

    function run() external {
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NumaFlashLender lender = new NumaFlashLender(NUMA_TOKEN);

        console.log("NumaFlashLender deployed at:", address(lender));

        vm.stopBroadcast();
    }
}
