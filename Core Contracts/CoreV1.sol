//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

import '../Poopcode/StandardTester_FakeDAO.sol';

/* 
* 
* Let's get this out of the way for now
* Please, let's try to keep it as API compatible as we can
contract HarmoniaDAO_V1_Core{
    //Variable Declarations
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;

    //Mapping, structs and other declarations
    
    Proposal[] Proposals;

    struct Proposal{
        uint256 ProposalID;
        uint8 ProposalType; //Type 0 is simple ether and asset sends, Type 1 are Proxy Proposals for external governance, Type 2 are Eros Prosposals
        uint256 RequestedEtherAmount; //Optional, can be zero
        uint256 RequestedAssetAmount; //Optional, can be zero
        uint8 RequestedAssetID;
        //proxy proposal entries here
        bool Executed; //Can only be executed once, when finished, proposal exist only as archive
    }



    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        TreasurySetter = msg.sender;
    }

    //Public state-modifing functions


    //Public view functions




    //Internal Executioning


    
    //One Time Functions
    function SetInitialTreasury(address TreasuryAddress) external{
        require(msg.sender == TreasurySetter);
        require(InitialTreasurySet == false);

        Treasury = TreasuryAddress;
        TreasurySetter = address(0); //Once the reasury address has been set for the first time, it can only be set again via proposal 
        InitialTreasurySet = true;

        emit NewTreasurySet(TreasuryAddress);
    }

    


    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }
}
*/
contract VotingSystemV1 {
    // Proposal executioner's bonus, proposal incentive burn percentage 
    FakeDAO public DAO;
    address public CLD;
    uint public MemberHolding;
    // These two are in Basis Points
    uint public ExecusCut;
    uint public BurnCut;

    event ProposalCreated(address proposer, string proposalName, uint voteStart, uint voteEnd);
    event ProposalPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event ProposalNotPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event CastedVote(uint proposalId, string option, uint votesCasted);
    event ProposalIncentivized(address donator, uint proposalId, uint amountDonated);
    event IncentiveWithdrawed(uint remainingIncentive);
    event NewDAOAddress(FakeDAO NewAddress);

    struct ProposalCore {
        string Name;
        uint VoteStarts;
        uint VoteEnds;
        uint8 Passed; // Can be 0 "Not voted", 1 "Passed" or 2 "Not Passed"
        uint ActiveVoters;
        uint ApprovingVotes;
        uint RefusingVotes;
        bool Executed;
        uint IncentiveAmount;
        uint IncentiveShare;
        uint AmountToBurn;
        uint AmountToExecutioner;
    }

    struct VoterInfo {
        uint votesLocked;
        uint amountDonated;
        bool voted;
        bool isExecutioner;  // TO DO this on Core?
    }

    // Proposals being tracked by id here
    ProposalCore[] internal proposal;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) internal voterInfo;
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    constructor(address CLDAddr, FakeDAO DAOAddr, uint8 _ExecusCut, uint8 _BurnCut) 
    {
        DAO = FakeDAO(msg.sender);
        // Setting the taxes
        SetTaxAmount(_ExecusCut, "execusCut");
        SetTaxAmount(_BurnCut, "burnCut");
        DAO = DAOAddr;
        CLD = CLDAddr;

        // TO DO insert poetic proposal #0 here
    }

    // To do people should lock tokens in order to propose?
    function CreateProposal(
        string memory _Name, 
        uint Time
        ) external OnlyDAO {
        require(Time != 0, "Proposals need an end time");

        // TO DO verify if this is useful
        // bytes32 _proposalName = keccak256(abi.encodePacked(_Name));
        // _checkForDuplicate(_proposalName);

        proposal.push(
            ProposalCore({
                Name: _Name,
                VoteStarts: block.timestamp,
                VoteEnds: block.timestamp + Time,
                Passed: 0, // Not voted yet
                ActiveVoters: 0,
                ApprovingVotes: 0,
                RefusingVotes: 0,
                Executed: false,
                IncentiveAmount: 0,
                IncentiveShare: 0,
                AmountToBurn: 0,
                AmountToExecutioner: 0
            })
        );

        emit ProposalCreated(msg.sender, _Name, block.timestamp, block.timestamp + Time);
    }

    function IncentivizeProposal(uint proposalId, uint amount) external {
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), 
        "You do not have enough CLD to stake this amount"
        );
        require(ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
        "You have not given the staking contract enough allowance"
        );
        // TO DO optimize this
        require(keccak256(
            abi.encodePacked(proposal[proposalId].Name,
            "Proposal doesn't exist")) != 0);
    
        require(block.timestamp <= proposal[proposalId].VoteEnds, 
        "The voting period has ended, save for the next proposal!"
        );
        // TO DO update incentiveshare
        proposal[proposalId].IncentiveAmount += amount;
        voterInfo[proposalId][msg.sender].amountDonated += amount;
        _updateTaxesAndIndIncentive(proposalId, true);

        emit ProposalIncentivized(msg.sender, proposalId, proposal[proposalId].IncentiveAmount);
    }

    function CastVote(
        uint amount,
        uint proposalId, 
        uint8 yesOrNo
        ) 
        external 
    { 
        require(
            ERC20(CLD).balanceOf(msg.sender) >= amount, 
            "You do not have enough CLD to vote this amount"
        );
        require(
            ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
            "You have not given the voting contract enough allowance"
        );
        require(
            yesOrNo == 0 || yesOrNo == 1, 
            "You must either vote 'Yes' or 'No'"
        );
        require(proposal[proposalId].Passed == 0, 'This proposal has ended');
        require(!voterInfo[proposalId][msg.sender].voted, "You already voted in this proposal");
        require(block.number < proposal[proposalId].VoteEnds, "The voting period has ended");

        ERC20(CLD).transferFrom(msg.sender, address(this), amount);

        if(yesOrNo == 0) {
            proposal[proposalId].ApprovingVotes += amount;
            emit CastedVote(proposalId, "Yes", amount);
        } else {
            proposal[proposalId].RefusingVotes += amount;
            emit CastedVote(proposalId, "No", amount);
        }
        voterInfo[proposalId][msg.sender].votesLocked += amount;
        voterInfo[proposalId][msg.sender].voted = true;
        proposal[proposalId].ActiveVoters += 1;

        _updateTaxesAndIndIncentive(proposalId, false);
    }

    // Proposal execution code
    // TO DO Take his out, we dont execute here
    function ExecuteProposal(uint proposalId) external { 
        voterInfo[proposalId][msg.sender].isExecutioner = true;

        require(keccak256(
            abi.encodePacked(proposal[proposalId].Name,
            "Proposal doesn't exist")) != 0);
        require(block.timestamp >= proposal[proposalId].VoteEnds, 
        "Voting has not ended");
        // TO DO Fix this
        require(proposal[proposalId].Passed == 0, "Proposal already executed!");
        require(proposal[proposalId].ActiveVoters > 0, "Can't execute proposals without voters!");

        uint burntAmount = _burnIncentiveShare(proposalId);
        ERC20(CLD).transfer(msg.sender, proposal[proposalId].AmountToExecutioner);
        proposal[proposalId].IncentiveAmount -= proposal[proposalId].AmountToExecutioner;

        if (proposal[proposalId].ApprovingVotes > proposal[proposalId].RefusingVotes) {
            // TO DO Execution
            proposal[proposalId].Passed = 1;

            emit ProposalPassed(msg.sender, proposalId, burntAmount, proposal[proposalId].AmountToExecutioner);
        } else {
            proposal[proposalId].Passed = 2;
            emit ProposalNotPassed(msg.sender, proposalId, burntAmount, proposal[proposalId].AmountToExecutioner);

        }

        proposal[proposalId].Executed = true;
        
    }

    function withdrawMyTokens(uint proposalId) external {
        if (proposal[proposalId].ActiveVoters > 0) {
            require(proposal[proposalId].Executed, 'Proposal has not been executed!');
            _returnTokens(proposalId, msg.sender, true);
        } else {
            _returnTokens(proposalId, msg.sender, true);
        }

        emit IncentiveWithdrawed(proposal[proposalId].IncentiveAmount);
    }

    function SetTaxAmount(uint amount, string memory taxToSet) public OnlyDAO returns (bool) {
        bytes32 _setHash = keccak256(abi.encodePacked(taxToSet));
        bytes32 _execusCut = keccak256(abi.encodePacked("execusCut"));
        bytes32 _burnCut = keccak256(abi.encodePacked("burnCut"));
        bytes32 _memberHolding = keccak256(abi.encodePacked("memberHolding"));

        if (_setHash == _execusCut) {
            require(amount >= 10 && amount <= 10000, 
            "Percentages can't be higher than 100");
            ExecusCut = amount;
        } else if (_setHash == _burnCut) {
            require(amount >= 10 && amount <= 10000, 
            "Percentages can't be higher than 100");
            BurnCut = amount;
        } else if (_setHash == _memberHolding) {
            MemberHolding = amount;
        } else {
            revert("You didn't choose a valid setting to modify!");
        }

        return true;
    }

    function ChangeDAO(FakeDAO newAddr) external OnlyDAO {
        _setDAOAddress(newAddr);
        emit NewDAOAddress(newAddr);
    }

    function SeeProposalInfo(uint proposalId) 
    public 
    view 
    returns (
     string memory,
        uint,
        uint,
        uint8,
        uint,
        uint,
        uint,
        bool,
        uint,
        uint,
        uint
    ) 
    {
        ProposalCore memory _proposal = proposal[proposalId];      
        return (
            _proposal.Name,
            _proposal.VoteStarts,
            _proposal.VoteEnds,
            _proposal.Passed,
            _proposal.ActiveVoters,
            _proposal.ApprovingVotes,
            _proposal.RefusingVotes,
            _proposal.Executed,
            _proposal.IncentiveAmount,
            _proposal.AmountToBurn,
            _proposal.AmountToExecutioner
            );
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // TO DO Refactor this
    function _returnTokens(
        uint _proposalId,
        address _voterAddr,
        bool _isItForProposals
        )
        internal {
        require(block.number > proposal[_proposalId].VoteEnds, "The voting period hasn't ended");

        uint _amount = voterInfo[_proposalId][_voterAddr].votesLocked;

        if(_isItForProposals) { // Debug only
            if (proposal[_proposalId].ActiveVoters > 0) {
                require(
                    voterInfo[_proposalId][_voterAddr].votesLocked > 0, 
                    "You need to lock votes in order to take them out"
                );
                uint _totalAmount = _amount;
                ERC20(CLD).transfer(_voterAddr, _totalAmount);
                // to do proposal[_proposalId].IncentiveAmount -= proposal[_proposalId].IncentiveShare; 
            } else {
                require(
                    voterInfo[_proposalId][_voterAddr].amountDonated > 0, 
                    "You have not incentivized this proposal"
                );
                uint incentiveToReturn = voterInfo[_proposalId][_voterAddr].amountDonated;
                ERC20(CLD).transfer(_voterAddr, incentiveToReturn);
                voterInfo[_proposalId][_voterAddr].amountDonated -= incentiveToReturn;
                proposal[_proposalId].IncentiveAmount -= incentiveToReturn;
            }
        } else {  // Debug only
            ERC20(CLD).transfer(_voterAddr, _amount);
        }
        voterInfo[_proposalId][_voterAddr].votesLocked -= _amount;
    }

    function _burnIncentiveShare(uint _proposalId) internal returns(uint) {
        uint amount = proposal[_proposalId].AmountToBurn;
        ERC20(CLD).Burn(amount);
        proposal[_proposalId].IncentiveAmount -= amount;

        return(amount);
    }
    // TO DO Verify this
    function _updateTaxesAndIndIncentive(uint _proposalId, bool allOfThem) internal  {
        if (allOfThem) {            
            uint newBurnAmount = proposal[_proposalId].IncentiveAmount * BurnCut / 100;
            proposal[_proposalId].AmountToBurn = newBurnAmount;

            uint newToExecutAmount = proposal[_proposalId].IncentiveAmount * ExecusCut / 100;
            proposal[_proposalId].AmountToExecutioner = newToExecutAmount;

            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        } else {
            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        }

    }

    function _setDAOAddress(FakeDAO _newAddr) internal {
        require(DAO != _newAddr, "VSystem.setDAOAddress:New DAO address can't be the same as the old one");
        require(address(_newAddr) != address(0), "VSystem.setDAOAddress: New DAO can't be the zero address");
        DAO = _newAddr;
    }

    function _updateIncentiveShare(uint _proposalId, uint _baseTokenAmount) internal {
       uint incentiveTaxes = proposal[_proposalId].AmountToBurn + proposal[_proposalId].AmountToExecutioner;
        uint totalTokenAmount = _baseTokenAmount - incentiveTaxes;
        if (proposal[_proposalId].ActiveVoters > 0) {
            uint newIndividualIncetive = totalTokenAmount / proposal[_proposalId].ActiveVoters;
            proposal[_proposalId].IncentiveShare = newIndividualIncetive;
        } else {
            proposal[_proposalId].IncentiveShare = totalTokenAmount;
        }
    }
    /* TO DO Verify this
    TO DO is this necessary?
    function _processProposal(uint8[] memory _values, address payable[] memory _targets, string[] memory _args) internal virtual {
        uint _processedArgs = _checkArgsGiveOption(_args);

        if (_processedArgs == 11) {
            FakeDAO(DAO).NewTreasuryAssetLimit(_values[0]);
        } else if (_processedArgs == 12) {
            FakeDAO(DAO).NewDAOInTreasury(_targets[0]);
        } else if (_processedArgs == 13) {
            FakeDAO(DAO).RegisterTreasuryAsset(_targets[0], 0);
        } else if (_processedArgs == 14) {
            FakeDAO(DAO).TreasuryERC20Transfer(_values[1], _values[2], _targets[0]);
        } else if (_processedArgs == 15) {
            FakeDAO(DAO).TreasuryEtherTransfer(_values[0], payable(_targets[0]));
        } else if (_processedArgs == 21) {
            FakeDAO(DAO).SetVotingAddress(_targets[0]);
        } else if (_processedArgs == 22) {
            FakeDAO(DAO).NewVotingTax(_values[0], _args[3]);
        } else if (_processedArgs == 31) {
            FakeDAO(DAO).SetVotingAddress(_targets[0]);
        } else if (_processedArgs == 32) {
            FakeDAO(DAO).SetTreasury(_targets[0]);
        }
    }

    /* @dev So this is pretty simple, actually:
    * if the hash of the strings passed as arguments match to the proposal`s
    * passed strings it will return a number (See Executioner.sol's interfaces to see the options)
    * All these will be handled by the frontend (still under designing)

    function _checkArgsGiveOption(string[] memory _arg) internal pure returns(uint option) {
        if (keccak256(abi.encodePacked(_arg[0])) == keccak256("Treasury")) {
            if (keccak256(abi.encodePacked(_arg[1])) == keccak256("Change")) {
                if (keccak256(abi.encodePacked(_arg[2])) == keccak256("ChangeRegisteredAssetLimit")) {
                    return 11;
                } else if (keccak256(abi.encodePacked(_arg[2])) == keccak256("ChangeDAOExecutioner")) {
                    return 12;
                } else if (keccak256(abi.encodePacked(_arg[2])) == keccak256("AddAsset")) {
                    return 13;
                } 
            } else if (keccak256(abi.encodePacked(_arg[1])) == keccak256("Send")) {
                 if (keccak256(abi.encodePacked(_arg[2])) == keccak256("SendRegisteredAsset")) {
                    return 14;
                } else if (keccak256(abi.encodePacked(_arg[2])) == keccak256("TransferEther")) {
                    return 15;
                }
            } // End of TREASURY 
        } else if (keccak256(abi.encodePacked(_arg[0])) == keccak256("VSystem")) {
            if (keccak256(abi.encodePacked(_arg[1])) == keccak256("setDAOAddress")) {            
                return 21;
            } else if (keccak256(abi.encodePacked(_arg[1])) == keccak256("setTaxAmount")) {
                return 22;
            } // End of VOTINGSYSTEM
        } else if (keccak256(abi.encodePacked(_arg[0])) == keccak256("DAOExec")) {
            if (keccak256(abi.encodePacked(_arg[1])) == keccak256("Set")) {
                if (keccak256(abi.encodePacked(_arg[2])) == keccak256("setVotingAddress")) {
                        return 31;
                } else if (keccak256(abi.encodePacked(_arg[2])) == keccak256("setTreasuryAddress")) {
                        return 32;
                }
            }  // End of DAOEXECUTIONER
        } else if (keccak256(abi.encodePacked(_arg[0])) == keccak256("External")) {
            return 4; // todo
        }
    }
    function _checkForDuplicate(bytes32 _proposalName) internal view {
        uint256 length = proposal.length;
        for (uint256 _proposalId = 0; _proposalId < length; _proposalId++) {
            bytes32 _nameHash = keccak256(abi.encodePacked(proposal[_proposalId].name));
            require(_nameHash != _proposalName, "This proposal already exists!");
        }
    }
    */
    /////////////////////////////////////////
    /////          Debug Tools          /////
    /////////////////////////////////////////

    function viewVoterInfo(
        address voter, 
        uint proposalId
        ) 
        external view returns (
        uint,
        uint,  
        bool 
    ) 
    {
        return (
            voterInfo[proposalId][voter].votesLocked,
            voterInfo[proposalId][voter].amountDonated,
            voterInfo[proposalId][voter].voted
        );
    }

    function takeMyTokensOut(uint proposalId) external {
        _returnTokens(proposalId,msg.sender,false);
    }

    function checkBlock() public view returns (uint){
        return block.number;
    }
}

 /////////////////////////////////////////
    /////          Interfaces           /////
    /////////////////////////////////////////

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
  function Burn(uint256 _BurnAmount) external;
}

//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface DAOTreasury{//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future,

}