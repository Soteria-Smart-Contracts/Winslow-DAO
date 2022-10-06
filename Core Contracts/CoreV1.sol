//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1_Core{
    address public Treasury;

    event FallbackToTreasury(uint256 amount);

    function SetTreasury(address TreasuryAddress) external{
        Treasury = TreasuryAddress;
    }


    receive() external payable{
        payable(Treasury).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }


}