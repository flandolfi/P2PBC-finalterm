pragma solidity ^0.4.20;

/// @title `BaseContentManager`: the Content Manager Interface
/// @author Francesco Landolfi
/// @notice This interface provides the basic set of functions that a content
///         manager should provide to interact with the `Catalog` contract
contract BaseContentManager {
    function getInfo() external view returns (address author, string title, uint genre);
    function grantAccess(address _account, uint _until) external;
    function consumeContent() external;
}