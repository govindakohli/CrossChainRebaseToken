// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IRebaseToken {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
    // function balanceOf(address _account) external view retruns(uint256);
    function balanceOf(address _account) external view returns (uint256);
}
