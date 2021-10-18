// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProvider {
    function get_address(uint256 _id) external view returns (address);
}
