// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
/**
 * @title RebaseToken
 * @author Govinda
 * @notice This is a cross-chain rebase token that incentivise users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    // error//
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    //State variables//
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;

    // Mapping ///
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    // Events///
    event InterestRateSet(uint256 newInterestRate);

    // Constructor ///
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _acount) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _acount);
    }

    /*
      *@notice Set the interest rate in the contract
      * @param  newInterestRate The new interest rate to set 
       *@dev The interest rate can only decrease
    */

    function setInterestrate(uint256 _newInterestrate) external onlyOwner {
        // set the interest rate
        if (_newInterestrate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestrate);
        }
        s_interestRate = _newInterestrate;
        emit InterestRateSet(_newInterestrate);
    }
    /*
    *@notice Get the principal balance of the user. This is the number of tokens that have currently been minted to the user , not including any interest that has accrued since the last time the user interacted
    with the protocol
    *@param _user The user to get the principal balance for 
    *@retrun The principal balance of the user
    */

    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
    /*
    * @notice Mint the user token when they deposit into the vault
    * @param _to The user to mint the token to
    * @param _amount The amount of tokens to mint
    */

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }
    /*
    * @notice Burn the user tokens when they withdraw from the vault
    * @param _from The user to burn the tokens from
    * @param _amount The amount of tokens to burn
     */

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }
    /*
    // * calculate the balance for the user including the interest that has accumulated since the last update 
    * (principle balance) + some interest that has accrued
    * @param _user The user to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the last update 
    */

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of token that actually been minted to the user)
        // multiply the principle balance by the interest that has accumulated in the time since the balance was lastupdated.
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    *@notice Transfer tokens from one user to another
    *@param _to The to transfer the tokens to 
    *@param _amount the amount of tokens to transfer
    *@return True if the transfer was successful
    */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    /*
    *@notice transfer tokens from one user to another
    *@param _from The user to transfer the tokens from
    *@param _to The user to transfer the tokens to 
    *@param _amount The amount of tokens to transfer
    *@return True if the transfer was successful
    */

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    ////
    //Internal function
    //////

    /*
    *@notice Calculate the interest that has accumulated since the last update 
    *@param _user The user to calculate the interest accumulated for 
    *@return The interest that has accumulated since the last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the last uodate
        // this is going to be linear groth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        //(principal amount) + (principal amount * user interest rate * time elapsed)
        // deposit: 10 tokens
        // interest rate 0.5 tokens per seconds
        // time elapsed is 2 seconds
        // 10 + ( 10 * 0.5 *2)
        uint256 timeElaspsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElaspsed);
    }

    /*
    /// @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g burn , mint , transfer)
    /// @param _user The user to mint the accrued interest to
    */
    function _mintAccruedInterest(address _user) internal {
        // (1) find theri current balance of rebase tokens that have been minted to the user -> principle
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // (2) calculate their current balance includuing any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // set the users last updated timestamp to now
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    /*
    *@notice Get the intrest rate that is currently set for the contract. Any future depositor will receive this interest rate 
    *@returns The interet rate for the contract
    */

    function getnterestrate() external view returns (uint256) {
        return s_interestRate;
    }

    /*
    *@notice Get the interest rate for the user 
    *@param _user The user to get the interest rate for 
    *@return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
