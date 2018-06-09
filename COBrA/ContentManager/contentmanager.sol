pragma solidity ^0.4.0;

contract ContentManager {
    bytes private data;
    bytes32 private fingerprint;
    uint private genre;
    string private description;
    string private title;
    address private author;
    address private publisher;
    mapping (address => uint) private grants;


    modifier onlyBy(address _account) {
        require(msg.sender == _account, "Permission denied");
        _;
    }

    constructor (bytes _data, string _title, string _description, uint _genre) public {
        require(
            _data.length > 0 && bytes(_title).length > 0 && bytes(_description).length > 0,
            "All input data must be non-empty"
        );

        data = _data;
        fingerprint = keccak256(_data);
        genre = _genre;
        title = _title;
        description = _description;
        author = msg.sender;
    }

    function setPublisher(address _publisher) external onlyBy(author) {
        publisher = _publisher;
    }

    function grantAccess(address _account, uint _until) external onlyBy(publisher) {
        require(_until >= now, "Grant already expired");
        require(grants[_account] < now, "Content already granted");
        grants[_account] = _until;
    }

    function getData() external returns (bytes) {
        require(grants[msg.sender] >= now, "Permission denied or expired");
        grants[msg.sender] = 0;

        return data;
    }

    function getInfo() external view returns (address, string, string, uint, bytes32) {
        return (author, title, description, genre, fingerprint);
    }
}
