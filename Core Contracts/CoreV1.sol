contract HarmoniaDAO_V1_Core{
    //Variable Declarations
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;

    //Mapping, structs and other declarations
    
    Proposal[] public Proposals;

    struct Proposal{
        uint256 ProposalID;
        uint8 ProposalType; //Type 0 is simple ether and asset sends plus DAO variable changes, Type 1 are Proxy Proposals for external governance, Type 2 are Eros Prosposals
        uint256 ProposalVotingLenght;
        uint256 RequestedEtherAmount; //Optional, can be zero
        uint256 RequestedAssetAmount; //Optional, can be zero
        uint8 RequestedAssetID;
        ProxyProposalArguments ProxyArgs;
        bool Executed; //Can only be executed once, when finished, proposal exist only as archive
    }

//How does it know what to call for Simple proposal? set up system, maybe some kind of int parser

    struct ProxyProposalArguments{
        uint256 UnsignedInt1;
        uint256 UnsignedInt2;
        uint256 UnsignedInt3; 
        address Address1;
        address Address2;
        address Address3;
        bool Bool1;
        bool Bool2;
        bool Bool3;
    }



    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        TreasurySetter = msg.sender;
    }

    //Public state-modifing functions


    //Public view functions




    //Internal Executioning

    function RegisterTreasuryAsset(address tokenAddress, uint8 slot, uint256 ProposalID) internal returns(bool success){

        TreasuryV1(Treasury).RegisterAsset(tokenAddress, slot);
    }

    function VerifyProposalAuthenticity(uint256 ProposalID, uint8 ExecutionType) internal returns(bool success){
        require(Proposals[ProposalID].ProposalType == ExecutionType);
        if(Proposals[ProposalID].RequestedAssetID != address(0)){
            require(Proposals[ProposalID].RequestedAssetID); //Require asset is registered
        }
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