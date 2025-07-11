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

/*
* @title RebaseToken
* @author Govinda   
* @notice This is a cross-chain rebase token that incentivise users to deposit into a vault and gain interest in rewards
* @notice The interest rate in the smart contract can only decrease
* @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing
*/
contract RebaseToken is ERC20 {
    // error//
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate , uint256 newInterestRate);

    //State variables//
    uint256 private s_interestRate = 5e10;

    // Mapping ///
    mapping (address => uint256 ) private s_userInterestRate;

    // Events///
    event InterestRateSet(uint256 newInterestRate);

   // Constructor ///
    constructor() ERC20("Rebase Token" , "RBT"){

    }
    
    /*/// @notice Set the interest rate in the contract
    /// @param  _newInterestRate The new interest rate to set 
    /// @dev The interest rate can only decrease
    */

    function setInterestrate(uint256 _newInterestrate) external{
            // set the interest rate 
            if(_newInterestrate < s_interestRate){
                revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate , _newInterestrate);
            }
            s_interestRate = _newInterestrate;
            emit InterestRateSet(_newInterestrate);
    }

    function mint(address _to , uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function _mintAccruedInterest(address _user) internal{
        // (1) find theri current balance of rebase tokens that have been minted to the user -> principle
        // (2) calculate their current balance includuing any interest -> balanceOf
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        // call _mint to mint the tokens to the user
        // set the users last updated timestamp to now

    }
        
}