// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from 'forge-std/test.sol';
import {FundMe} from '../../src/FundMe.sol';
import {DeployFundMe} from '../../script/DeployFundMe.s.sol';

contract FundMeTest is Test {
  FundMe fundMe;
  DeployFundMe deployFundMe;

  address USER = makeAddr("user");
  uint256 constant SEND_VALUE = 0.1 ether;
  uint256 constant STARTING_VALUE = 10 ether;
  uint256 constant GAS_PRICE = 1;

  function setUp() external {
   // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
   deployFundMe = new DeployFundMe();
   fundMe = deployFundMe.run();
   vm.deal(USER, STARTING_VALUE);
  }

  function testMinimumDollarIsFive() public {
    assertEq(fundMe.MINIMUM_USD(), 5e18);
  }

  function testOwnerIsMsgSender() public {
    assertEq(fundMe.getOwner(), msg.sender);
  }

  function testPriceFeedVersionIsAccurate() public {
    uint256 version = fundMe.getVersion();
    assertEq(version, 4);
  }

  function testFundFailsWithoutEnoughETH() public {
    vm.expectRevert();
    fundMe.fund();
  }

  function testFundUpdatesFundedDataStructure() public {
    vm.prank(USER);
    fundMe.fund{value: SEND_VALUE}();
    uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
    assertEq(amountFunded, SEND_VALUE);
  }

  function testAddsFunderToArrayofFunders() public {
    vm.prank(USER);
    fundMe.fund{value: SEND_VALUE}();
    address funder = fundMe.getFunder(0);
    assertEq(USER, funder);
  }

  modifier funded() {
    vm.prank(USER);
    fundMe.fund{value: SEND_VALUE}();
    _;
  }

  function testOnlyOwnerCanWithdraw() public funded {
    vm.expectRevert();
    vm.prank(USER);
    fundMe.withdraw();
  }

  function testWithdrawWithASingleFunder() public funded {
    uint256 startingOwnerBalance = fundMe.getOwner().balance;
    uint256 startingContractBalance = address(fundMe).balance;

    vm.txGasPrice(GAS_PRICE);
    vm.prank(fundMe.getOwner());
    fundMe.withdraw();

    uint256 endingOwnerBalance = fundMe.getOwner().balance;
    uint256 endingContractBalance = address(fundMe).balance;

    assertEq(endingContractBalance, 0);
    assertEq(startingOwnerBalance + startingContractBalance, endingOwnerBalance);
  }

  function testWithdrawFromMultipleFunders() public funded {
    uint160 numberOfFunders = 10;
    uint160 startingFunderIndex = 1;

    for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
      hoax(address(i), SEND_VALUE);
      fundMe.fund{value: SEND_VALUE}();
    }

   uint256 startingOwnerBalance = fundMe.getOwner().balance;
    uint256 startingContractBalance = address(fundMe).balance;

    vm.startPrank(fundMe.getOwner());
    fundMe.withdraw();
    vm.stopPrank();

    assert(address(fundMe).balance == 0);
    assert(startingContractBalance + startingOwnerBalance == fundMe.getOwner().balance);
  }

   function testWithdrawFromMultipleFundersCheaper() public funded {
    uint160 numberOfFunders = 10;
    uint160 startingFunderIndex = 1;

    for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
      hoax(address(i), SEND_VALUE);
      fundMe.fund{value: SEND_VALUE}();
    }

   uint256 startingOwnerBalance = fundMe.getOwner().balance;
    uint256 startingContractBalance = address(fundMe).balance;

    vm.startPrank(fundMe.getOwner());
    fundMe.cheaperWithdraw();
    vm.stopPrank();

    assert(address(fundMe).balance == 0);
    assert(startingContractBalance + startingOwnerBalance == fundMe.getOwner().balance);
  }
}
