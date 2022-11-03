//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1_Core{
    //Variable Declarations
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;

    //Mapping, structs and other declarations


    struct Proposal{
        uint256 ProposalID;
        uint8 ProposalType; //Type 0 is simple ether and asset sends, Type 1 are Proxy Proposals for external governance, Type 2 are Eros Prosposals
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
//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface DAOTreasury{//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future,

}