// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {SoccerVault} from "../src/Soccer.sol";
import {NFT} from "../src/SoccerNft.sol";
import {SoccerERC20} from "../src/soccerERC.sol";

contract SoccerTest is Test {
    SoccerVault public soccer;
    NFT public soccerNft;
    SoccerERC20 soccerERC20;

    function setUp() public {
        soccerNft = new NFT("Soccer NFT", "SOC", "base");
        soccerERC20 = new SoccerERC20();
        soccer = new SoccerVault(address(soccerERC20), address(soccerNft));
        soccerERC20.approve(address(soccer), 100*10**18);
        soccer.createListing(100*10**18, 60);
        soccer.executeListing(1, "sfdfafdfdgad");
        soccer.createBid(1);
        soccer.placeBid(1, 100*10**18);
    }

    function test_executeBid() public {
       
        vm.warp(block.timestamp+61 seconds);

        soccer.executeBid(1);
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
