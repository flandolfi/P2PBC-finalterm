pragma solidity ^0.4.20;

import "./basecontentmanager.sol";

/// @title COBrA: Fair Content Trade on the BlockChain
/// @author Francesco Landolfi
/// @notice This contract provides a set of functionalities to manage he trading
///         of multimedial contents. The `Catalog` contract acts as an 
///         intermediary between `ContentManage` contracts.
contract Catalog {

    /// @dev Although it may seem redundant, `ContentCredit` stores the total 
    ///      credit owed to an author. This could have been simply evaluated 
    ///      with `contentViews*contentFee`, but the owner of the catalog may
    ///      change the value of contentFee at any time.
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

    address private owner;
    address[] private authors;
    address[] private contents;

    uint private premiumCredit = 0 ether;
    uint private premiumViews = 0;

    /// @notice The number of views needed for an author to withdraw his credit
    uint public payableViews = 30;

    /// @notice The period of time that must pass between the partition and
    ///         distribution of the credit collected by premium subsctiprions
    uint public premiumWithdrawalPeriod = 120 days;

    /// @notice The last time in which the premium credit has been transferred
    uint public lastPremiumWithdrawal;

    /// @notice The price of a single-content subscription
    uint public contentFee = 0.2 finney;

    /// @notice The price of a premium subscription
    uint public premiumFee = 10 finney;

    /// @notice The period of time in which a consumer can get the acquired 
    ///         content
    uint public contentPeriod = 3 days;

    /// @notice The period of validity of a premium subscription
    uint public premiumPeriod = 30 days;

    // Events (self-explanatory)
    event NewAuthor(address author);
    event NewContentPublished(address content, address author, string title, uint genre);
    event NewPremiumSubscription(address account, uint until);
    event CreditAvailable(address account);
    event CreditTransferred(address account);


    /// @notice The constructor of the catalog
    /// @dev The creator becomes the owner of the catalog, remaining so for the
    ///      whole life-time of the catalog (the variable `owner` cannot be
    ///      modified)
    constructor() public {
        owner = msg.sender;
        lastPremiumWithdrawal = now;
    }

    /// @notice Modifier for limiting access to owner of the catalog
    modifier onlyOwner() {
        require(msg.sender == owner, "Permission denied");
        _;
    }

    /// @notice Modifier used to check the amount of value in a `payable` 
    ///         function
    /// @param _value the expected `value` of the transaction
    modifier hasValue(uint _value) {
        require(msg.value == _value, "Wrong value");
        _;
    }

    /// @notice Changes the price of the single-content subscriptions.
    /// @param _fee The new price
    function setContentFee(uint _fee) external onlyOwner() {
        contentFee = _fee;
    }

    /// @notice Changes the price of the premium subscriptions.
    /// @param _fee The new price
    function setPremiumFee(uint _fee) external onlyOwner() {
        premiumFee = _fee;
    }

    /// @notice Changes the validity time of the single-content subscriptions.
    /// @param _period The new period
    function setContentPeriod(uint _period) external onlyOwner() {
        contentPeriod = _period;
    }

    /// @notice Changes the validity time of the premium subscriptions.
    /// @param _period The new period
    function setPremiumPeriod(uint _period) external onlyOwner() {
        premiumPeriod = _period;
    }

    /// @notice Changes the period of time that must pass between the partition
    ///         and distribution of the credit collected by premium 
    ///         subsctiprions
    /// @param _period The new period
    function setPremiumWithdrawalPeriod(uint _period) external onlyOwner() {
        premiumWithdrawalPeriod = _period;
    }

    /// @notice Changes the number of views needed for an author to withdraw his
    ///         credit
    /// @param _views The new view count threshold
    function setPayableViews(uint _views) external onlyOwner() {
        payableViews = _views;
    }

    /// @notice Publish a new content
    /// @param _content the address of a `ContentManager` contract
    /// @dev The contract must provide the interface of `BaseContentManager`
    function publish(address _content) external {
        address author;
        string memory title;
        uint genre;

        BaseContentManager manager = BaseContentManager(_content);
        (author, title, genre) = manager.getInfo();
        require(msg.sender == author, "Only the author of the content can publish it");
        require(contentInfos[_content].author == address(0), "Content already published");
        contents.push(_content);
        contentInfos[_content] = ContentInfo(author, genre, 0);

        if (!authorInfos[author].registered) {
            authorInfos[author] = AuthorInfo(0, 0, 0, true);
            authors.push(author);
            emit NewAuthor(author);
        }

        emit NewContentPublished(_content, author, title, genre);
    }

    /// @notice Checks if an account has an active premium subscription
    /// @param _account the address of the consumer
    /// @return True if `_account` has an active premium subscription, false
    ///         otherwise
    function isPremium(address _account) public view returns (bool) {
        return premiumAccounts[_account] >= now;
    }

    /// @notice Subscribe `msg.sender` to a premium subscription
    function buyPremium() external payable hasValue(premiumFee) {
        giftPremium(msg.sender);
    }

    /// @notice Subscribe `_account` to a premium subscription
    /// @param _account The address of the consumer to subscribe
    function giftPremium(address _account) public hasValue(premiumFee) {
        uint expirationTime = premiumAccounts[_account];
        expirationTime = (expirationTime > now? expirationTime : now) + premiumPeriod;
        premiumAccounts[_account] = expirationTime;
        premiumCredit += premiumFee;
        emit NewPremiumSubscription(_account, expirationTime);
    }

    /// @dev Utility function to grant `_account` the access to `_content` until
    ///      `_until`
    /// @param _content The address of the `ContentManager` contract
    /// @param _account The address of the consumer
    /// @param _until The expiration date of the grant 
    function _grantContent(address _content, address _account, uint _until) private {
        require(contentInfos[_content].author != address(0), "Content not found");
        BaseContentManager manager = BaseContentManager(_content);
        manager.grantAccess(_account, _until);
        contentInfos[_content].views++;
    }

    /// @notice Grant the access to a given content
    /// @param _content The address of the `ContentManager` contract
    function getContent(address _content) external payable hasValue(contentFee) {
        giftContent(_content, msg.sender);
    }

    /// @notice Donate a content access to a given user
    /// @param _content The address of the `ContentManager` contract
    /// @param _account The address of the recipient
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

    /// @notice Grant the premium access to a given content
    /// @param _content The address of the `ContentManager` contract
    function getContentPremium(address _content) external {
        require(isPremium(msg.sender), "Premium subscription not found or expired");
        _grantContent(_content, msg.sender, premiumAccounts[msg.sender]);
        authorInfos[contentInfos[_content].author].premiumViews++;
        premiumViews++;
    }

    /// @notice Get the list of the published contents
    /// @return An array of `ContentManager` addresses
    function getContentList() external view returns (address[]) {
        return contents;
    }

    /// @notice Get the list of the published contents, together with the number
    ///         of views for each content
    /// @return An array of `ContentManager` `address`es and an array of `uint`s
    function getStatistics() external view returns (address[], uint[]) {
        uint[] memory views = new uint[](contents.length);

        for (uint i = 0; i < contents.length; i++) {
            views[i] = contentInfos[contents[i]].views;
        }

        return (contents, views);
    }

    /// @notice Get the last `_size` published contents
    /// @param _size The number of newest contents to be returned
    /// @return An array of size `_size` of `address`es
    function getNewContentList(uint _size) external view returns (address[]) {
        address[] memory newests = new address[](_size);

        for (uint i = 0; i < _size && i < contents.length; i++) {
            newests[i] = contents[contents.length - 1 - i];
        }

        return newests;
    }

    /// @notice Get the last published content of a given genre
    /// @param _genre The identifier of a genre
    /// @return The address of the last published content that has genre
    ///         `_genre`. If no such content has been published, returns a
    ///         zero-address
    function getLatestByGenre(uint _genre) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contentInfos[contents[i]].genre == _genre) {
                return contents[i];
            }
        }

        return address(0);
    }

    /// @notice Get the last published content of a given author
    /// @param _author The address of an author
    /// @return The address of the last published content published by
    ///         `_author`. If no such content has been published, returns a
    ///         zero-address
    function getLatestByAuthor(address _author) external view returns (address) {
        for (uint i = contents.length - 1; i >= 0; i--) {
            if (contentInfos[contents[i]].author == _author) {
                return contents[i];
            }
        }

        return address(0);
    }

    /// @notice Get the most popular (in view count) content of a given genre
    /// @param _genre The identifier of a genre
    /// @return The address of the most popular content that has genre
    ///         `_genre`. If no such content has been published, returns a
    ///         zero-address. In case of tie, returns the most recent one
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

    /// @notice Get the most popular (in view count) content of a given author
    /// @param _author The address of an author
    /// @return The address of the most popular content published by
    ///         `_author`. If no such content has been published, returns a
    ///         zero-address. In case of tie, returns the most recent one
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

    /// @notice Transfer to `msg.sender` the credit collected by (non-premium)
    ///         content fruitions. An author may call this function only if 
    ///         the total number of views of its contents is greater than
    ///         `payableViews`
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

    /// @notice Partition and transfer all the collected premium credit among
    ///         all the registered authors. Any user can call this function,
    ///         even if is not an author or the owner of the catalog, but can
    ///         only be called once every `premiumWithdrawalPeriod` seconds.
    ///         This is done to increase the fairness of the partitions, which
    ///         evaluated proportionally to the number of premium accesses to
    ///         the authors' contents.
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

    /// @notice Transfer all the residual credit among the authors and \
    ///         self-destroys the catalog.
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