//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_V1_Treasury{
    address public DAO;
    uint256 public RegisteredAssetLimit = 5;
    Token public ClassicDAO;
    address[] public RegisteredAssets;

    struct Token{
        uint16 DAOid;
        address TokenAddress;
        uint256 DAObalance;
    }

    constructor(address DAOcontract){
        DAO = DAOcontract;

    }










}