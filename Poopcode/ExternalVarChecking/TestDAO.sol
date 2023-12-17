//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        string Memo;
        uint256 Yay;
        uint256 Nay;

        bool executed;
        bool passed;
        mapping(address => bool) voters;
    }
}