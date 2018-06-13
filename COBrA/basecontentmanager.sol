pragma solidity ^0.4.20;

contract BaseContentManager {
    event AccessGranted(address to, uint until);
    event ContentConsumed(address by);

    function getInfo() external view returns (address, string, uint);
    function grantAccess(address _account, uint _until) external;
    function consumeContent() external;
}