// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FundingStudent} from "../src/funding.sol";
import {FundToken} from "../src/FundingToken.sol";

contract FundingTest is Test {
    FundToken fundToken;
    FundingStudent fundingStudent;

    string imageHash = "dafdgagdgadgdgdga";
    string title = "School Fees";
    string  description = "I don't have money";
    uint256 amount = 2000;
    string  referral = "Mr. Dangote";

   
    function setUp() public {
        fundToken = new FundToken();
        fundingStudent = new FundingStudent(address(fundToken));
    }

    function test_registerStudent() public {
        fundingStudent.registerStudent(imageHash);
        vm.expectRevert("Student is already registered");
        fundingStudent.registerStudent(imageHash);
    }

    function test_createProposal() public {
        vm.expectRevert("Not a student");
        fundingStudent.createProposal(title,description,amount,imageHash,referral);
        
        fundingStudent.registerStudent(imageHash);
        fundingStudent.revokeStudent(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        vm.expectRevert("Not a student");
        fundingStudent.createProposal(title,description,amount,imageHash,referral);

        fundingStudent.registerStudent(imageHash);
        fundingStudent.createProposal(title,description,amount,imageHash,referral);
    }

    function test_approveProposal() public {
        fundingStudent.registerStudent(imageHash);
        uint256 id = fundingStudent.createProposal(title,description,amount,imageHash,referral);
        vm.expectRevert();
        vm.prank(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        fundingStudent.approveProposal(id);

        fundingStudent.approveProposal(id);
    }

    function test_donate() public {
        fundingStudent.registerStudent(imageHash);
        uint256 id = fundingStudent.createProposal(title,description,amount,imageHash,referral);
        fundingStudent.approveProposal(id);
        vm.expectRevert("Insufficient balance");
        vm.prank(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        fundingStudent.donate(500, id);

        fundToken.transfer(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 2000);
        fundToken.transfer(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 2000);

        vm.startPrank(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        fundToken.approve(address(fundingStudent), 2000);
        fundingStudent.donate(2000, id);
        vm.stopPrank();
        assertTrue(fundToken.balanceOf(address(fundingStudent)) == 2000);

        vm.startPrank(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        fundToken.approve(address(fundingStudent), 500);
        vm.expectRevert();
        fundingStudent.donate(500, id);
    }

    function test_disburse() public{
        fundingStudent.registerStudent(imageHash);
        uint256 id = fundingStudent.createProposal(title,description,amount,imageHash,referral);
        vm.expectRevert();
        fundingStudent.disburseFund(id);
        fundingStudent.approveProposal(id);

        fundToken.transfer(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 1500);
        fundToken.transfer(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 2000);
        
        vm.startPrank(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        fundToken.approve(address(fundingStudent), 1500);
        fundingStudent.donate(1500, id);
        vm.stopPrank();

        vm.expectRevert();
        fundingStudent.disburseFund(id);

        vm.startPrank(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        fundToken.approve(address(fundingStudent), 1500);
        fundingStudent.donate(500, id);
        vm.stopPrank();

        fundingStudent.disburseFund(id);
        vm.expectRevert();
        fundingStudent.disburseFund(id);
    }

    function test_withdraw() public {
        vm.startPrank(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        fundingStudent.registerStudent(imageHash);
        uint256 id = fundingStudent.createProposal(title,description,amount,imageHash,referral);
        vm.stopPrank();

        fundingStudent.approveProposal(id);

        fundToken.transfer(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 2000);
        
        vm.startPrank(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        fundToken.approve(address(fundingStudent), 2000);
        fundingStudent.donate(2000, id);
        vm.stopPrank();

        fundingStudent.disburseFund(id);

        vm.expectRevert();
        fundingStudent.withdraw(2000);

        vm.startPrank(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        vm.expectRevert();
        fundingStudent.withdraw(2500);

        fundingStudent.withdraw(2000);

        vm.stopPrank();
        assertEq(fundToken.balanceOf(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2), 2000);

        vm.prank(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        vm.expectRevert();
        fundingStudent.withdraw(10);
    }

    

    

}