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
        address author;
        uint genre;
        uint views;
    }

    mapping (address => AuthorInfo) private authorInfos;
    mapping (address => ContentInfo) private contentInfos;
    mapping (address => uint) private premiumAccounts;
    mapping (bytes32 => bool) private publishedContents;

    address private owner;
    address[] private authors;
    address[] private contents;

    uint private premiumCredit = 0 ether;
    uint private premiumViews = 0;

    uint public payableViews = 30;
    uint public premiumWithdrawalPeriod = 120 days;
    uint public lastPremiumWithdrawal;
    uint public contentFee = 0.0002 ether;
    uint public contentPeriod = 3 days;
    uint public premiumFee = 0.01 ether;
    uint public premiumPeriod = 30 days;

    event NewAuthor(address author);
    event NewContentPublished(address content, address author, string title, uint genre);
    event NewPremiumSubscription(address account, uint until);
    event ContentGranted(address content, address account, uint until);
    event CreditAvailable(address account);
    event CreditTransferred(address account);


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
        string memory title;
        uint genre;
        bytes32 fingerprint;
        BaseContentManager manager = BaseContentManager(_content);
        (author, title, genre, fingerprint) = manager.getInfo();
        require(msg.sender == author, "Only the author of the content can publish it");
        require(
            !publishedContents[fingerprint] && contentInfos[_content].author == address(0), 
            "Content already published"
        );
        contents.push(_content);
        contentInfos[_content] = ContentInfo(author, genre, 0);
        publishedContents[fingerprint] = true;

        if (!authorInfos[author].registered) {
            authorInfos[author] = AuthorInfo(0, 0, 0, true);
            authors.push(author);
            emit NewAuthor(author);
        }

        emit NewContentPublished(_content, author, title, genre);
    }

    function buyPremium() external payable hasValue(premiumFee) {
        uint expirationTime = premiumAccounts[msg.sender];
        expirationTime = (expirationTime > now? expirationTime : now) + premiumPeriod;
        premiumAccounts[msg.sender] = expirationTime;
        premiumCredit += premiumFee;
        emit NewPremiumSubscription(msg.sender, expirationTime);
    }

    function _grantContent(address _content, address _account, uint _until) private {
        require(contentInfos[_content].author != address(0), "Content not found");
        BaseContentManager manager = BaseContentManager(_content);
        manager.grantAccess(_account, _until);
        contentInfos[_content].views++;
        emit ContentGranted(_content, _account, _until);
    }

    function getContent(address _content) external payable hasValue(contentFee) {
        _grantContent(_content, msg.sender, now + contentPeriod);
        address author = contentInfos[_content].author;
        AuthorInfo storage info = authorInfos[author];
        info.contentViews++;
        info.contentCredit += contentFee;

        if (info.contentViews >= payableViews) {
            emit CreditAvailable(author);
        }
    }

    function giftContent(address _content, address _account) public payable hasValue(contentFee) {
        _grantContent(_content, _account, now + contentPeriod);
        address author = contentInfos[_content].author;
        AuthorInfo storage info = authorInfos[author];
        info.contentViews++;
        info.contentCredit += contentFee;

        if (info.contentViews >= payableViews) {
            emit CreditAvailable(author);
        }
    }

    function getContentPremium(address _content) external {
        require(isPremium(msg.sender), "Premium subscription not found or expired");
        _grantContent(_content, msg.sender, premiumAccounts[msg.sender]);
        authorInfos[contentInfos[_content].author].premiumViews++;
        premiumViews++;
    }

    function getContentList() external view returns (address[]) {
        return contents;
    }

    function getStatistics() external view returns (address[], uint[]) {
        uint[] memory views = new uint[](contents.length);

        for (uint i = 0; i < contents.length; i++) {
            views[i] = contentInfos[contents[i]].views;
        }

        return (contents, views);
    }

    function getNewContentList(uint _size) external view returns (address[]) {
        address[] memory newests = new address[](_size);

        for (uint i = 0; i < _size && i < contents.length; i++) {
            newests[i] = contents[contents.length - 1 - i];
        }

        return newests;
    }

    function getLatestByGenre(uint _genre) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contentInfos[contents[i]].genre == _genre) {
                return contents[i];
            }
        }

        return address(0);
    }

    function getLatestByAuthor(address _author) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contentInfos[contents[i]].author == _author) {
                return contents[i];
            }
        }

        return address(0);
    }

    function getMostPopularByGenre(uint _genre) external view returns (address) {
        address mostPopular;
        uint mostPopularViews;

        for (uint i = 0; i < contents.length; i++) {
            ContentInfo memory info = contentInfos[contents[i]];

            if (info.genre == _genre && info.views >= mostPopularViews) {
                mostPopular = contents[i];
                mostPopularViews = info.views;
            }
        }

        return mostPopular;
    }

    function getMostPopularByAuthor(address _author) external view returns (address) {
        address mostPopular;
        uint mostPopularViews;

        for (uint i = 0; i < contents.length; i++) {
            ContentInfo memory info = contentInfos[contents[i]];

            if (info.author == _author && info.views >= mostPopularViews) {
                mostPopular = contents[i];
                mostPopularViews = info.views;
            }
        }

        return mostPopular;
    }

    function withdraw() external {
        AuthorInfo storage info = authorInfos[msg.sender];
        require(info.registered, "No contents found");
        require(info.contentViews >= payableViews, "View count threshold not reached yet");
        uint credit = info.contentCredit;
        info.contentCredit = 0;
        info.contentViews = 0;
        msg.sender.transfer(credit);
        emit CreditTransferred(msg.sender);
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
                uint credit = (premiumCredit*info.premiumViews)/premiumViews;
                info.premiumViews = 0;
                author.transfer(credit);
                emit CreditTransferred(author);
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
                    uint credit = info.contentCredit + (premiumCredit*info.premiumViews)/premiumViews;
                    info.contentCredit = 0;
                    info.premiumViews = 0;
                    author.transfer(credit);
                    emit CreditTransferred(author);
                }
            }
        }

        selfdestruct(owner);
    }
}