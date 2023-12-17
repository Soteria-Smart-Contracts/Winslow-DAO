//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        uint256 ID;
        uint256 Yay;
        string Nay;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) voters;
    }
}