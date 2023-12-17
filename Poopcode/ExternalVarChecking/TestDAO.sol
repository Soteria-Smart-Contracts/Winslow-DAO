//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        string Memo;
        uint256 ID;
        uint256 Yay;
        uint256 Nay;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) voters;
    }
}