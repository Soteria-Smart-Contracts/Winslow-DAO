//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_V1_Treasury{
    address public DAO;
    uint256 public RegisteredAssetLimit = 5;
    address[] public RegisteredAssets

    constructor(address DAOcontract){
        DAO = DAOcontract;
    }










}