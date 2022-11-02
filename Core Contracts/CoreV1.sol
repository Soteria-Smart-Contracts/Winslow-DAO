//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

import '../Poopcode/StandardTester_FakeDAO.sol';

/* 
* 
* Let's get this out of the way for now
* Please, let's try to keep it as API compatible as we can
contract HarmoniaDAO_V1_Core{
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;


    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        TreasurySetter = msg.sender;
    }

    
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
contract VotingSystem {
    //using Arrays for uint256[];

    // Proposal executioner's bonus, proposal incentive burn percentage 
    address internal cld;
    uint public execusCut;
    uint public burnCut;
    uint public memberHolding;
    address payable public DAOExecutioner;
    bool hasDAOExecutioner = false;

    event ProposalCreated(address proposer, string proposalName, uint voteStart, uint voteEnd);
    event ProposalPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event ProposalNotPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event CastedVote(uint proposalId, string option, uint votesCasted);
    event ProposalIncentivized(address donator, uint proposalId, uint amountDonated);
    event IncentiveWithdrawed(uint remainingIncentive);
    event NewDAOExecutionerAddress(address NewAddress);

    struct ProposalCore {
        string name;
        uint voteStart;
        uint voteEnd;
        bool executed;
        uint activeVoters;
        uint approvingVotes;
        uint refusingVotes;
        uint incentiveAmount;
        uint incentiveShare;
        uint amountToBurn;
        uint amountToExecutioner;
        bool passed; // Can be "Not voted", "Passed" or "Not Passed"
    }

    struct ProposalContext {
        address[] externalContract;
        uint[] values;
        string[] callOptions;
    }

    struct VoterInfo {
        uint votesLocked;
        uint amountDonated;
        bool voted;
        bool isExecutioner;
    }

    struct ExternalContracts {
        address Contract;
    }

    // Proposals being tracked by id here
    ProposalCore[] internal proposal;
    // Proposals being tracked by id here
    ProposalContext[] internal proposalContext;
    // ExternalContracts being tracked by id here
    ExternalContracts[] externalContract;
    // ProposalContext being tracked by their proposal ID
    // mapping (uint256 => mapping (uint256 => ProposalContext)) internal proposalContext;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) internal voterInfo;
 
     modifier OnlyDAO() {
        _checkIfDAO();
        _;
    }

    constructor(address cldAddr) 
    {
        cld = cldAddr;
        burnCut = 10;
        execusCut = 10;
        DAOExecutioner = payable(msg.sender);
    }

    // To do people should lock tokens in order to propose?
    function createProposal(
        string memory name, 
        uint time,
        uint256[] memory _values, 
        address[] memory extContract, 
        string[] memory callArgs
        ) external {
        require(ERC20(cld).balanceOf(msg.sender) >= memberHolding, "Sorry, you are not a DAO member");
        require(keccak256(abi.encode(name)) != 0, "Proposals need a name");
        require(time != 0, "Proposals need an end time");
        for (uint256 i = 0; i < extContract.length; ++i) {
            require(extContract[i] != address(0), "External contracts can't be the 0 address");
        }
        bytes32 hashCallArgs = keccak256(abi.encodePacked(callArgs[0]));
        require(hashCallArgs != 0, "Proposals needs arguments");

        bytes32 _proposalName = keccak256(abi.encodePacked(name));
        _checkForDuplicate(_proposalName);

        uint beginsNow = block.number;
        uint endsIn = block.number + time;
        proposal.push(
            ProposalCore({
                name: name,
                voteStart: beginsNow,
                voteEnd: endsIn,
                executed: false,
                activeVoters: 0,
                approvingVotes: 0,
                refusingVotes: 0,
                incentiveAmount: 0,
                incentiveShare: 0,
                amountToBurn: 0,
                amountToExecutioner: 0,
                passed: false // False until voted, once executed is understood it didn't pass
            })
        );

        proposalContext.push(
            ProposalContext({
                externalContract: extContract,
                values: _values,
                callOptions: callArgs
            })
        );

        emit ProposalCreated(msg.sender, name, beginsNow, endsIn);
    }

    function incentivizeProposal(uint proposalId, uint amount) external {
        require(ERC20(cld).balanceOf(msg.sender) >= amount, 
        "You do not have enough CLD to stake this amount"
        );
        require(ERC20(cld).allowance(msg.sender, address(this)) >= amount, 
        "You have not given the staking contract enough allowance"
        );
        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        
        require(block.number < proposal[proposalId].voteEnd, 
        "The voting period has ended, save for the next proposal!"
        );

        ERC20(cld).transferFrom(msg.sender, address(this), amount);
        proposal[proposalId].incentiveAmount += amount;
        voterInfo[proposalId][msg.sender].amountDonated += amount;
        _updateTaxesAndIndIncentive(proposalId, true);

        emit ProposalIncentivized(msg.sender, proposalId, proposal[proposalId].incentiveAmount);
    }

    function castVote(
        uint amount,
        uint proposalId, 
        uint8 yesOrNo
        ) 
        external 
    { 
        require(
            ERC20(cld).balanceOf(msg.sender) >= amount, 
            "You do not have enough CLD to vote this amount"
        );
        require(
            ERC20(cld).allowance(msg.sender, address(this)) >= amount, 
            "You have not given the voting contract enough allowance"
        );
        require(
            yesOrNo == 0 || yesOrNo == 1, 
            "You must either vote 'Yes' or 'No'"
        );
        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        require(!voterInfo[proposalId][msg.sender].voted, "You already voted in this proposal");
        require(block.number < proposal[proposalId].voteEnd, "The voting period has ended");

        ERC20(cld).transferFrom(msg.sender, address(this), amount);

        if(yesOrNo == 0) {
            proposal[proposalId].approvingVotes += amount;
            emit CastedVote(proposalId, "Yes", amount);
        } else {
            proposal[proposalId].refusingVotes += amount;
            emit CastedVote(proposalId, "No", amount);
        }
        voterInfo[proposalId][msg.sender].votesLocked += amount;
        voterInfo[proposalId][msg.sender].voted = true;
        proposal[proposalId].activeVoters += 1;

        _updateTaxesAndIndIncentive(proposalId, false);
    }

    // Proposal execution code
    // Placeholder TO DO
    function executeProposal(uint proposalId) external { 
        voterInfo[proposalId][msg.sender].isExecutioner = true;

        require(keccak256(
            abi.encodePacked(proposal[proposalId].name,
            "Proposal doesn't exist")) != 0);
        require(proposal[proposalId].voteEnd <= block.number, "Voting has not ended");
        require(!proposal[proposalId].executed, "Proposal already executed!");
        require(proposal[proposalId].activeVoters > 0, "Can't execute proposals without voters!");

        uint burntAmount = _burnIncentiveShare(proposalId);
        uint executShare = proposal[proposalId].amountToExecutioner;
        ERC20(cld).transfer(msg.sender, executShare);
        proposal[proposalId].incentiveAmount -= proposal[proposalId].amountToExecutioner;

        if (proposal[proposalId].approvingVotes > proposal[proposalId].refusingVotes) {
            proposal[proposalId].passed = true;
            // execute payload sending a .execute to the Executor TO DO
            _processProposal(proposalContext[proposalId].values, 
            proposalContext[proposalId].externalContract,
            proposalContext[proposalId].callOptions);

            //     function _processProposal(uint256[] memory _values, string[] memory _args, address[] memory _targets) internal virtual {
            emit ProposalPassed(msg.sender, proposalId, burntAmount, executShare);
            /*
        function addValuesWithCall(address calculator, uint256 a, uint256 b) public returns (uint256) {
        (bool success, bytes memory result) = calculator.call(abi.encodeWithSignature("add(uint256,uint256)", a, b));
        emit AddedValuesByCall(a, b, success);
        return abi.decode(result, (uint256));*/
        } else {
            proposal[proposalId].passed = false;
            emit ProposalNotPassed(msg.sender, proposalId, burntAmount, executShare);

        }

        proposal[proposalId].executed = true;
        
    }

    function withdrawMyTokens(uint proposalId) external {
        if (proposal[proposalId].activeVoters > 0) {
            require(proposal[proposalId].executed, 'Proposal has not been executed!');
            _returnTokens(proposalId, msg.sender, true);
        } else {
            _returnTokens(proposalId, msg.sender, true);
        }

        emit IncentiveWithdrawed(proposal[proposalId].incentiveAmount);
    }

    function setTaxAmount(uint amount, string calldata taxToSet) external OnlyDAO returns (bool) {
        require(amount < 100, "Percentages can't be higher than 100");
        require(amount > 0, "This tax can't be zeroed!");
        bytes32 _setHash = keccak256(abi.encodePacked(taxToSet));
        bytes32 _execusCut = keccak256(abi.encodePacked("execusCut"));
        bytes32 _burnCut = keccak256(abi.encodePacked("burnCut"));
        bytes32 _memberHolding = keccak256(abi.encodePacked("memberHolding"));

        if (_setHash == _execusCut) {
            execusCut = amount;
        } else if (_setHash == _burnCut) {
            burnCut = amount;
        } else if (_setHash == _memberHolding) {
            memberHolding = amount;
        } else {
            revert("You didn't choose a valid setting to modify!");
        }

        return true;
    }

    function setDAOAddress(address payable newAddr) external OnlyDAO {
        _setDAOAddress(newAddr);
        emit NewDAOExecutionerAddress(newAddr);

    }

    function seeProposalInfo(uint proposalId) 
    public 
    view 
    returns (
        string memory,
        uint,
        uint,
        bool,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        bool
    ) 
    {
        ProposalCore memory _proposal = proposal[proposalId];      
        return (
            _proposal.name,
            _proposal.voteStart,
            _proposal.voteEnd,
            _proposal.executed,
            _proposal.activeVoters,
            _proposal.approvingVotes,
            _proposal.refusingVotes,
            _proposal.incentiveAmount,
            _proposal.incentiveShare,
            _proposal.amountToBurn,
            _proposal.amountToExecutioner,
            _proposal.passed
            );
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // WIP [TEST REQUIRED]
    function _returnTokens(
        uint _proposalId,
        address _voterAddr,
        bool _isItForProposals
        )
        internal {
        require(block.number > proposal[_proposalId].voteEnd, "The voting period hasn't ended");

        uint _amount = voterInfo[_proposalId][_voterAddr].votesLocked;

        if(_isItForProposals) { // Debug only
            if (proposal[_proposalId].activeVoters > 0) {
                require(
                    voterInfo[_proposalId][_voterAddr].votesLocked > 0, 
                    "You need to lock votes in order to take them out"
                );
                uint _totalAmount = _amount + proposal[_proposalId].incentiveShare;
                ERC20(cld).transfer(_voterAddr, _totalAmount);
                proposal[_proposalId].incentiveAmount -= proposal[_proposalId].incentiveShare; 
            } else {
                require(
                    voterInfo[_proposalId][_voterAddr].amountDonated > 0, 
                    "You have not incentivized this proposal"
                );
                uint incentiveToReturn = voterInfo[_proposalId][_voterAddr].amountDonated;
                ERC20(cld).transfer(_voterAddr, incentiveToReturn);
                voterInfo[_proposalId][_voterAddr].amountDonated -= incentiveToReturn;
                proposal[_proposalId].incentiveAmount -= incentiveToReturn;
            }
        } else {  // Debug only
            ERC20(cld).transfer(_voterAddr, _amount);
        }
        voterInfo[_proposalId][_voterAddr].votesLocked -= _amount;
    }

    function _burnIncentiveShare(uint _proposalId) internal returns(uint) {
        uint amount = proposal[_proposalId].amountToBurn;
        ERC20(cld).Burn(amount);
        proposal[_proposalId].incentiveAmount -= amount;

        return(amount);
    }

    function _updateTaxesAndIndIncentive(uint _proposalId, bool allOfThem) internal {
        uint baseTokenAmount = proposal[_proposalId].incentiveAmount;

        if (allOfThem) {            
            uint newBurnAmount = baseTokenAmount * burnCut / 100;
            proposal[_proposalId].amountToBurn = newBurnAmount;

            uint newToExecutAmount = baseTokenAmount * execusCut / 100;
            proposal[_proposalId].amountToExecutioner = newToExecutAmount;

            _updateIncentiveShare(_proposalId, baseTokenAmount);
        } else {
            _updateIncentiveShare(_proposalId, baseTokenAmount);
        }

    }

    function _setDAOAddress(address payable _newAddr) internal {
        require(DAOExecutioner != _newAddr, "VSystem.setDAOAddress:New DAO address can't be the same as the old one");
        require(_newAddr != address(0), "VSystem.setDAOAddress: New DAO can't be the zero address");
        DAOExecutioner = _newAddr;
    }

    function _updateIncentiveShare(uint _proposalId, uint _baseTokenAmount) internal {
        uint incentiveTaxes = proposal[_proposalId].amountToBurn + proposal[_proposalId].amountToExecutioner;
        uint totalTokenAmount = _baseTokenAmount - incentiveTaxes;
        if (proposal[_proposalId].activeVoters > 0) {
             uint newIndividualIncetive = totalTokenAmount / proposal[_proposalId].activeVoters;
            proposal[_proposalId].incentiveShare = newIndividualIncetive;
        } else {
            proposal[_proposalId].incentiveShare = totalTokenAmount;
        }
    }

    function _processProposal(uint256[] memory _values, address payable[] memory _targets, string[] memory _args) internal virtual {
        uint _processedArgs = _checkArgsGiveOption(_args);

        if (_processedArgs == 11) {
            FakeDAO(DAOExecutioner).NewTreasuryAssetLimit(_values[0]);
        } else if (_processedArgs == 12) {
            FakeDAO(DAOExecutioner).ChangeDAO(_targets[0]);
        } else if (_processedArgs == 13) {
            FakeDAO(DAOExecutioner)._AddAsset(_targets[0], 0);
        } else if (_processedArgs == 14) {
            FakeDAO(DAOExecutioner)._SendRegisteredAsset(_values[1], _targets[0], _values[0]);
        } else if (_processedArgs == 15) {
            FakeDAO(DAOExecutioner)._TransferEther(_values[0], payable(_targets[0]));
        } else if (_processedArgs == 21) {
            FakeDAO(DAOExecutioner).setDAOAddress(_targets[0]);
        } else if (_processedArgs == 22) {
            FakeDAO(DAOExecutioner).setVSysTax(_values[0], _args[3]);
        } else if (_processedArgs == 31) {
            FakeDAO(DAOExecutioner).setVotingAddress(_targets[0]);
        } else if (_processedArgs == 32) {
            FakeDAO(DAOExecutioner).setTreasuryAddress(_targets[0]);
        }
    }

    /* @dev So this is pretty simple, actually:
    * if the hash of the strings passed as arguments match to the proposal`s
    * passed strings it will return a number (See Executioner.sol's interfaces to see the options)
    * All these will be handled by the frontend (still under designing)
    */
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

    function _checkIfDAO() internal view {
        require(msg.sender == DAOExecutioner, "This function can only be called by the DAO");
    }

    function _checkForDuplicate(bytes32 _proposalName) internal view {
        uint256 length = proposal.length;
        for (uint256 _proposalId = 0; _proposalId < length; _proposalId++) {
            bytes32 _nameHash = keccak256(abi.encodePacked(proposal[_proposalId].name));
            require(_nameHash != _proposalName, "This proposal already exists!");
        }
    }

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

library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

/**
 * @dev Collection of functions related to array types.
 */
library Arrays {
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    function removeElement(uint256[] storage _array, uint256 _element) public {
        for (uint256 i; i<_array.length; i++) {
            if (_array[i] == _element) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                break;
            }
        }
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