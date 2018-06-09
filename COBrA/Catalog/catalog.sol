pragma solidity ^0.4.20;

import "./basecontentmanager.sol";

contract Catalog {
    struct AuthorInfo {
        uint contentCredit;
        uint contentViews;
        uint premiumViews;
        bool registered;
    }

    struct ContentInfo {
        address manager;
        address author;
        uint genre;
        uint views;
    }

    mapping (address => AuthorInfo) private authorInfos;
    mapping (address => uint) private premiumAccounts;
    mapping (bytes32 => bool) private publishedContents;

    address private owner;
    address[] private authors;
    ContentInfo[] private contents;

    uint private premiumCredit = 0 ether;
    uint private premiumViews = 0;

    uint public payableViews = 30;
    uint public premiumWithdrawalPeriod = 120 days;
    uint public lastPremiumWithdrawal;
    uint public contentFee = 0.0002 ether;
    uint public contentPeriod = 3 days;
    uint public premiumFee = 0.01 ether;
    uint public premiumPeriod = 30 days;

    event newAuthor(address _author);
    event newContentPublished(address _content, address _author, uint _genre);
    event newPremiumSubscription(address _account, uint _until);
    event contentGranted(address _content, address _account, uint _until);
    event creditAvailable(address _account);
    event creditTransferred(address _account);


    constructor() public {
        owner = msg.sender;
        lastPremiumWithdrawal = now;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Permission denied");
        _;
    }

    modifier hasValue(uint _value) {
        require(msg.value == _value, "Wrong value");
        _;
    }

    function isPremium(address _account) public view returns (bool) {
        return premiumAccounts[_account] >= now;
    }

    function setPremiumFee(uint _fee) external onlyOwner() {
        premiumFee = _fee;
    }

    function setPremiumPeriod(uint _period) external onlyOwner() {
        premiumPeriod = _period;
    }

    function setPremiumWithdrawalPeriod(uint _period) external onlyOwner() {
        premiumWithdrawalPeriod = _period;
    }

    function setPayableViews(uint _views) external onlyOwner() {
        payableViews = _views;
    }

    function publish(address _content) external {
        address author;
        uint genre;
        bytes32 fingerprint;
        BaseContentManager manager = BaseContentManager(_content);
        (author, , , genre, fingerprint) = manager.getInfo();
        require(msg.sender == author, "Only the author of the content can publish it");
        require(!publishedContents[fingerprint], "Content already published");
        contents.push(ContentInfo(_content, author, genre, 0));
        publishedContents[fingerprint] = true;

        if (!authorInfos[author].registered) {
            authorInfos[author] = AuthorInfo(0, 0, 0, true);
            emit newAuthor(author);
        }

        emit newContentPublished(_content, author, genre);
    }

    function buyPremium() external payable hasValue(premiumFee) {
        uint expirationTime = premiumAccounts[msg.sender];
        expirationTime = (expirationTime > now? expirationTime : now) + premiumPeriod;
        premiumAccounts[msg.sender] = expirationTime;
        premiumCredit += premiumFee;
        emit newPremiumSubscription(msg.sender, expirationTime);
    }

    function _grantContent(uint _contentID, address _account, uint _until) private {
        BaseContentManager manager = BaseContentManager(contents[_contentID].manager);
        manager.grantAccess(_account, _until);
        contents[_contentID].views++;
        emit contentGranted(manager, _account, _until);
    }

    function getContent(uint _contentID) external payable hasValue(contentFee) {
        _grantContent(_contentID, msg.sender, now + contentPeriod);
        address author = contents[_contentID].author;
        AuthorInfo storage info = authorInfos[author];
        info.contentViews++;
        info.contentViews += contentFee;

        if (info.contentViews > payableViews) {
            emit creditAvailable(author);
        }
    }

    function giftContent(uint _contentID, address _account) public payable hasValue(contentFee) {
        _grantContent(_contentID, _account, now + contentPeriod);
        address author = contents[_contentID].author;
        AuthorInfo storage info = authorInfos[author];
        info.contentViews++;
        info.contentViews += contentFee;

        if (info.contentViews > payableViews) {
            emit creditAvailable(author);
        }
    }

    function getContentPremium(uint _contentID) external {
        require(isPremium(msg.sender), "Premium subscription not found or expired");
        _grantContent(_contentID, msg.sender, premiumAccounts[msg.sender]);
        authorInfos[contents[_contentID].author].premiumViews++;
        premiumViews++;
    }

    function getContentList() external view returns (address[]) {
        address[] memory result = new address[](contents.length);

        for (uint i = 0; i < contents.length; i++) {
            result[i] = contents[i].manager;
        }

        return result;
    }

    function getStatistics() external view returns (address[], uint[]) {
        address[] memory managers = new address[](contents.length);
        uint[] memory views = new uint[](contents.length);

        for (uint i = 0; i < contents.length; i++) {
            managers[i] = contents[i].manager;
            views[i] = contents[i].views;
        }

        return (managers, views);
    }

    function getNewContentList(uint _size) external view returns (address[]) {
        address[] memory newests = new address[](_size);

        for (uint i = 0; i < _size && i < contents.length; i++) {
            newests[i] = contents[contents.length - 1 - i].manager;
        }

        return newests;
    }

    function getLatestByGenre(uint _genre) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contents[i].genre == _genre) {
                return contents[i].manager;
            }
        }

        return address(0);
    }

    function getLatestByAuthor(address _author) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contents[i].author == _author) {
                return contents[i].manager;
            }
        }

        return address(0);
    }

    function getMostPopularByGenre(uint _genre) external view returns (address) {
        address mostPopular;
        uint mostPopularViews;

        for (uint i = 0; i < contents.length; i++) {
            if (contents[i].genre == _genre && contents[i].views >= mostPopularViews) {
                mostPopular = contents[i].manager;
                mostPopularViews = contents[i].views;
            }
        }

        return mostPopular;
    }

    function getMostPopularByAuthor(address _author) external view returns (address) {
        address mostPopular;
        uint mostPopularViews;

        for (uint i = 0; i < contents.length; i++) {
            if (contents[i].author == _author && contents[i].views >= mostPopularViews) {
                mostPopular = contents[i].manager;
                mostPopularViews = contents[i].views;
            }
        }

        return mostPopular;
    }

    function withdraw() external {
        AuthorInfo storage senderInfo = authorInfos[msg.sender];
        require(senderInfo.registered, "No contents found");
        require(senderInfo.contentViews >= payableViews, "View count threshold not reached yet");
        uint credit = senderInfo.contentCredit;
        senderInfo.contentCredit = 0;
        senderInfo.contentViews = 0;
        msg.sender.transfer(credit);
        emit creditTransferred(msg.sender);
    }

    function transferPremiumCredits() public {
        require(
            lastPremiumWithdrawal + premiumWithdrawalPeriod < now, 
            "Premium accounts retribuition period not yet passed"
        );

        require(premiumViews > 0, "No premium content consumed since last retribution :(");
        lastPremiumWithdrawal = now;

        for (uint i = 0; i < authors.length; i++) {
            address author = authors[i];
            AuthorInfo storage info = authorInfos[author];
            
            if (info.premiumViews > 0) {
                uint credit = premiumCredit*info.premiumViews/premiumViews;
                info.premiumViews = 0;
                author.transfer(credit);
                emit creditTransferred(author);
            }
        }

        premiumCredit = 0;
        premiumViews = 0;
    }

    function closeCatalog() external onlyOwner() {
        if (premiumViews > 0) {
            for (uint i = 0; i < authors.length; i++) {
                address author = authors[i];
                AuthorInfo memory info = authorInfos[author];

                if (info.contentCredit > 0 || info.premiumViews > 0) {
                    uint credit = info.contentCredit + premiumCredit*info.premiumViews/premiumViews;
                    info.contentCredit = 0;
                    info.premiumViews = 0;
                    author.transfer(credit);
                    emit creditTransferred(author);
                }
            }
        }

        selfdestruct(owner);
    }
}