//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract allows and keeps track of commitee member votes on safety ratings for proposal*/
pragma solidity ^0.8.17;

contract Winslow_Security_Commitee_V1{
    //Variable and other Declarations
    string public Version = "V1";
    address public DAO;
    uint256 public TotalMembers;
    address[] public CommiteeMembers;
    
    mapping(address => bool) public CommiteeMember;
    mapping(uint256 => uint256) internal MemberIndex;

    enum ProposalSecurityRating{
        Excellent,
        Good,
        Average,
        Poor,
        Risky,
        Critical
    }

    struct ProposalSecurityVote{
        mapping(ProposalSecurityRating => uint256);
        uint256 TotalVotes;
    }

    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    } 

    //DAO Only Functions
    
    function 



    //View Functions

    function AllMembers() public view returns(address[] Members){
        return(CommiteeMembers);
    }
}