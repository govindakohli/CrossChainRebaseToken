// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        // (bool sucess,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public {
        (bool sucess,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2.check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        console.log("rebase token balance", rebaseToken.balanceOf(user));
        console.log(" Amount ", amount);
        // 2. redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount , uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // 1. deposit
        vm.deal(user,depositAmount);
        vm.prank(user);
        vault.deposit{value:depositAmount}();

        // 2. warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        // 2. (b) add the rewards to the vault
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardToVault(balanceAfterSomeTime - depositAmount);
        
        // 3. redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);
        vm.stopPrank();

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        // assertEq(ethBalance , depositAmount);
    }

    function testTransfer(uint256 amount , uint256 amountToSend) public {
        amount = bound(amount,1e5 + 1e5 ,type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
    
       // 1. deposit
       vm.deal(user , amount);
       vm.prank(user);
       vault.deposit{value:amount}();

       address user2 = makeAddr("user2");
       uint256 userBalance = rebaseToken.balanceOf(user);
       uint256 user2Balance = rebaseToken.balanceOf(user2);
       assertEq(userBalance, amount);
       assertEq(user2Balance, 0);

       // owner reduces the interest rsste 
       vm.prank(owner);
       rebaseToken.setInterestrate(4e10);

       // 2. transfer
       vm.prank(user);
       rebaseToken.transfer(user2, amountToSend);
       uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
       uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
       assertEq(userBalanceAfterTransfer , userBalance - amountToSend);
       assertEq(user2BalanceAfterTransfer, amountToSend);
       

       // check the user interest rate has been inherited (5e10 not 4e10)
       assertEq(rebaseToken.getUserInterestRate(user),5e10);
       assertEq(rebaseToken.getUserInterestRate(user2), 5e10);


    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestrate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user,100);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user , 100);
    }

    function testGetPrincipalAmount(uint256 amount) public {
        amount = bound(amount, 1e5 , type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value:amount}();
        assertEq(rebaseToken.principalBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principalBalanceOf(user), amount);

    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestrate) public {
        uint256 initialInterestrate = rebaseToken.getnterestrate();
        newInterestrate = bound(newInterestrate, initialInterestrate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestrate(newInterestrate);
        assertEq(rebaseToken.getnterestrate(),initialInterestrate);
    }
}
