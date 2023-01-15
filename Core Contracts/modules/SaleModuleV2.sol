//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract provides a factory and sale contract for the Winslow Core to initiate sales of CLD from the treasury*/
pragma solidity ^0.8.17;

contract SaleFactoryV2{

}

contract SaleV2{
    //  Variable, struct, mapping and other Declarations
    //  Core
    address public DAO;
    address public CLD;
    address public Treasury;
    uint256 public SaleNumber; //This iteration of all CLD sales conducted
    uint256 public StartTime; //Unix Time
    uint256 public EndTime;   //Unix Time
    uint256 public CLDToBeSold; //Total amount of CLD being offered for sale by the DAO
    //  Fees in basis points, chosen by proposer/al on deploy, so can be 0
    uint256 public MinimumDeposit; //Minimum amount of Ether to be deposited when calling the deposit function
    uint256 public DAOFoundationFee; //Fee that goes directly to the foundation for further development
    uint256 public RetractFee; //Fee that is charged when a user removes their ether from the pool, to count as totaletherpool
    // Details
    uint256 public TotalEtherPool; //Defines the total amount of ether deposited by participators
    uint256 public TotalRetractionFeesAccrued; //Total amount of ether received from retraction fees 

    enum SaleStatuses{ 
        Uncommenced, //Before the sale, allowing users to view the amount of CLD that will sold and additional information
        Ongoing,     //While the sale is active, allowing users to deposit or withdraw ETC from the pool 
        Complete     //After the sale is complete, allowing users to withdraw their CLD in which they purchased
    }

    struct Participant{ 
        bool Participated;
        bool CLDclaimed;
        uint256 EtherDeposited;
        uint256 CLDWithdrawn;
    }

    //TODO: dont forget events on all contracts
    
    //Mapping for participants
    mapping(address => Participant) public ParticipantDetails; 
    //List of participants for front-end ranking
    address[] public ParticipantList; 

    constructor(address _DAO, uint256 CLDtoSell, uint256 SaleLength, uint256 FoundationFee, uint256 RetractionFee){
        require(SaleLength >= 259200 && SaleLength <= 1209600);
        DAO = _DAO;
        Treasury = Core(DAO).TreasuryContract();
        CLD = Core(DAO).CLDAddress();
        CLDToBeSold = CLDtoSell; //Make sure CLD is transfered to contract after treasury, additional CLD sent to the sale contract will be lost
        StartTime = block.timestamp + 43200;
        EndTime = StartTime + SaleLength;
        DAOFoundationFee = FoundationFee;
        RetractFee = RetractionFee;
    }

    //  During Sale
    //Deposit ETC

    function DepositEther() public payable returns(bool success){
        require(SaleStatus() == SaleStatuses(1));
        require(msg.value >= MinimumDeposit); 

        if(ParticipantDetails[msg.sender].Participated = false){
            ParticipantDetails[msg.sender].Participated = true;
            ParticipantList.push(msg.sender);
        }

        ParticipantDetails[msg.sender].EtherDeposited += msg.value;
        TotalEtherPool += msg.value;

        return(success);
    }

    function WithdrawEther(uint256 amount) public returns(bool success){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(amount <= ParticipantDetails[msg.sender].EtherDeposited);
        require(SaleStatus() == SaleStatuses(1));

        uint256 Fee = ((amount * RetractFee) / 10000);

        TotalRetractionFeesAccrued += Fee;
        ParticipantDetails[msg.sender].EtherDeposited -= amount;

        return(success);
    }


    function ClaimCLD() public returns(bool success, uint256 AmountClaimed){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(ParticipantDetails[msg.sender].CLDclaimed == false);
        require(SaleStatus() == SaleStatuses(2));
        ParticipantDetails[msg.sender].CLDclaimed = true;


        uint256 CLDtoSend = ((CLDToBeSold *  ParticipantDetails[msg.sender].EtherDeposited) / TotalEtherPool);
        ParticipantDetails[msg.sender].CLDWithdrawn = CLDtoSend;



        return(success, )
    }




    //View Functions

    function SaleStatus() public view returns(SaleStatuses Status){
        if(block.timestamp < StartTime){
            return(SaleStatuses(0));
        }
        if(block.timestamp > StartTime && block.timestamp < EndTime){
            return(SaleStatuses(1));
        }
        if(block.timestamp > EndTime){
            return(SaleStatuses(2));
        }
        else{
            revert("Error on getting sale status");
        }
    }




}

interface Core {
    function TreasuryContract() external returns(address payable TreasuryAddress);
    function CLDAddress() external view returns(address CLD);
}