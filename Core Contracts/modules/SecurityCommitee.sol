//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract allows and keeps track of commitee member votes on safety ratings for proposal*/
pragma solidity ^0.8.17;

contract Winslow_Security_Commitee_V1{
    address DAO;

    uint256 TotalMembers;
    address[] CommiteeMembers;
    
    mapping(address => bool) CommiteeMember;

    enum ProposalSecurityRating{
        Excellent,
        Good,
        Average,
        Poor,
        Risky,
        Critical
    }

    struct ProposalSecurityVote{

    }






}