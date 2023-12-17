//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        uint256 id;
        uint256 voteCount;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) voters;
    }
}