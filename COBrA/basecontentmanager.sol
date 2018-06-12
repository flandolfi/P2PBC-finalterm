pragma solidity ^0.4.20;

contract BaseContentManager {
    function grantAccess(address _account, uint _until) external;
    function getInfo() external view returns (address, string, uint, bytes32);
    function getData() external returns (bytes);
}