//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1_Core{
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    

    event FallbackToTreasury(uint256 amount);

    
    //One Time Functions
    function SetTreasury(address TreasuryAddress) external{
        Treasury = TreasuryAddress;
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