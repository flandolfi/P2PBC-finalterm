pragma solidity ^0.4.0;

import "./basecontentmanager.sol";

/// @title The `ContentManager` Contract
/// @author Francesco Landolfi
/// @notice This contract manages the access and consumption of the content
contract ContentManager is BaseContentManager {
    uint private genre;
    string private title;
    address private author;
    address private publisher;
    mapping (address => uint) private grants;

    // Events
    event AccessGranted(address to, uint until);
    event ContentConsumed(address by);


    /// @notice Modifier for limiting access to a certain user
    modifier onlyBy(address _account) {
        require(msg.sender == _account, "Permission denied");
        _;
    }

    /// @notice The constructor of the content manager
    /// @param _title The title of the content
    /// @param _genre The identifier of the genre
    /// @dev This constructor sets `mag.sender` as the author of the content.
    ///      This should remain unmodified
    constructor(string _title, uint _genre) public {
        require(bytes(_title).length > 0, "All input data must be non-empty");
        genre = _genre;
        title = _title;
        author = msg.sender;
    }

    /// @notice Grants access to a catalog contract. This function should be
    ///         called before publishing this content to the same catalog. If
    ///         not set, any transaction to `grantAccess()` called by the
    ///         catalog will fail. Only the author of this content can call this
    ///         function
    /// @param _publisher The address of the `Catalog` contract 
    function trustPublisher(address _publisher) external onlyBy(author) {
        publisher = _publisher;
    }

    /// @notice Grants access to a given consumer until a certain date. Only the
    ///         set publisher contract can call this function
    /// @param _account The address of the consumer
    /// @param _until The expiration date of the grant
    function grantAccess(address _account, uint _until) external onlyBy(publisher) {
        require(_until >= now, "Grant already expired");
        require(grants[_account] < now, "Content already granted");
        grants[_account] = _until;
        emit AccessGranted(_account, _until);
    }

    /// @notice Consume the content and expires the grant assigned to
    ///         `msg.sender`
    function consumeContent() external {
        require(grants[msg.sender] >= now, "Permission denied or expired");
        grants[msg.sender] = 0;
        emit ContentConsumed(msg.sender);
    }

    /// @notice Get information about the content, namely the author, the title
    ///         and the genre
    /// @return A tuple of
    ///          - an `address`, the address of the author of the content
    ///          - a `string`, the title of the content
    ///          - a `uint`, the identifier of the genre of the content
    function getInfo() external view returns (address, string, uint) {
        return (author, title, genre);
    }
}
