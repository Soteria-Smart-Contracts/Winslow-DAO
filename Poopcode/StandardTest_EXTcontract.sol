//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract ImExternal{
    string public Information;
    uint public Integer;

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(address(this)), "The caller is either not the DAO or not approved by the DAO");
        _;
    }

    function UpdateString() public 


}