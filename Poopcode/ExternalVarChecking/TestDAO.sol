//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        uint256 ID;
        uint256 YesVotes;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) voters;
    }
}