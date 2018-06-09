pragma solidity ^0.4.20;

contract BaseContentManager {
    function setPublisher(address _publisher) external;
    function grantAccess(address _account, uint _until) external;
    function getData() external returns (bytes);
    function getInfo() external view returns (address, string, string, uint, bytes32);
}