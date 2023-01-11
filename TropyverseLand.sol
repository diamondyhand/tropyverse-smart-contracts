// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/IERC2981.sol";

contract TropyverseLand is Ownable, ERC721Enumerable, ERC721URIStorage {
    // Keep a mapping of used IPFS hashes
    mapping(string => uint8) private usedTokenURIs;
    // Keep number of token minted by address
    mapping(address => uint256) private addressMintedBalance;
    // Keep used nonce for replay attack
    mapping(string => bool) private usedNonce;

    // Maximum amounts of mintable tokens
    uint256 private constant MAX_SUPPLY = 10200;
    uint256 constant MAX_PER_WALLET = 10;
    uint256 constant PURCHASE_LIMIT = 5;

    // collection metadata uri
    string _contractURI;
    // Address of the royalties recipient
    address private _royaltiesReceiver;
    // Address sales manager
    address payable manager;
    // signer address
    address signerAddress;

    address minterContract;
    // referral program
    // Percentage of each sale to pay as royalties
    uint256 public royaltiesPercentage = 10;
    // Keep public sale status
    bool public isMintActive = false;
    bool public isAdminMintActive = true;

    struct Token {
        string tokenURI;
        uint256 tokenId;
    }

    // Events
    event NewToken(address indexed _receiver, uint256 _tokenId, string ipfsUri);
    event Withdraw(address indexed _receiver, uint256 _amount);

    // modifiers
    modifier onlyAuthorized() {
        require(
            msg.sender == minterContract || msg.sender == owner(),
            "Caller is not authorized"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        string memory _collectionURI,
        address _signerAddress,
        address _initialRoyaltiesReceiver
    ) ERC721(_name, _symbol) {
        manager = payable(_manager);
        _contractURI = _collectionURI;
        signerAddress = _signerAddress;
        _royaltiesReceiver = _initialRoyaltiesReceiver;
    }

    // override functions
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(_tokenId), "Token doesn't exists");
        uint256 _royalties = (_salePrice * royaltiesPercentage) / 100;
        return (_royaltiesReceiver, _royalties);
    }

    function royaltiesReceiver() external view returns (address) {
        return _royaltiesReceiver;
    }

    function setRoyaltiesReceiver(address newRoyaltiesReceiver)
        external
        onlyOwner
    {
        require(newRoyaltiesReceiver != _royaltiesReceiver);
        _royaltiesReceiver = newRoyaltiesReceiver;
    }

    function setRoyaltyPercentage(uint256 _percent)
        external
        onlyOwner
        returns (uint256)
    {
        require(_percent > 0 && _percent < 50, "Invalid Royalty value");
        royaltiesPercentage = _percent;
        return _percent;
    }

    function getManager() external view onlyAuthorized returns (address) {
        return manager;
    }

    function setManager(address payable _manager)
        external
        onlyOwner
        returns (address payable)
    {
        require(manager != _manager, "Trying to set current manager");
        manager = _manager;
        return _manager;
    }

    function setPublicSaleActive(bool _status) external onlyOwner {
        isMintActive = _status;
    }

    function setAdminMint(bool _status) external onlyOwner {
        isAdminMintActive = _status;
    }

    // get and set signer address
    function getSignerAddress() external view onlyAuthorized returns (address) {
        return signerAddress;
    }

    function setSignerAddress(address _signer) external onlyOwner {
        require(
            signerAddress != _signer,
            "Trying to set current signer address"
        );
        signerAddress = _signer;
    }

    // get and set function for referral program contrac address

    // check balance of contract
    function checkBalance() external view onlyOwner returns (uint256 balance) {
        return address(this).balance;
    }

    // withdraw eth from contract
    function withdrawEthers(uint256 amount) external onlyOwner {
        require((amount <= address(this).balance), "insufficient balance");
        (bool _withdrawSent, ) = payable(owner()).call{value: amount}("");
        require(_withdrawSent, "Failed to send Ether");
        emit Withdraw(owner(), amount);
    }

    // this function mint tokens with agent and recruiter referral

    function publicMint(address _to, string memory _uri) external {
        require(isMintActive == true, "Sale is disabled");
        require(usedTokenURIs[_uri] != 1, "Token is already minted");
        uint256 ownerMintedCount = addressMintedBalance[_to];
        require(
            (ownerMintedCount + 1) <= MAX_PER_WALLET,
            "Exceeded per wallet!"
        );
        require(totalSupply() + 1 <= MAX_SUPPLY, "Max Supply reached");
        usedTokenURIs[_uri] = 1;

        uint256 newTokenId = totalSupply() + 1;

        _safeMint(_to, newTokenId);

        _setTokenURI(newTokenId, _uri);
        addressMintedBalance[_to] += 1;

        emit NewToken(_to, newTokenId, _uri);
    }

    function adminMint(address _to, string memory _uri)
        external
        onlyAuthorized
    {
        require(isAdminMintActive == true, "Sale is disabled");
        require(usedTokenURIs[_uri] != 1, "Token is already minted");
        uint256 ownerMintedCount = addressMintedBalance[_to];
        require(
            (ownerMintedCount + 1) <= MAX_PER_WALLET,
            "Exceeded per wallet!"
        );
        require(totalSupply() + 1 <= MAX_SUPPLY, "Max Supply reached");
        usedTokenURIs[_uri] = 1;

        uint256 newTokenId = totalSupply() + 1;

        _safeMint(_to, newTokenId);

        _setTokenURI(newTokenId, _uri);
        addressMintedBalance[_to] += 1;

        emit NewToken(_to, newTokenId, _uri);
    }

    // internal functions

    function tokensOfOwner(address _owner)
        external
        view
        returns (Token[] memory ownerTokens)
    {
        uint256 tokenCount = balanceOf(_owner);
        Token[] memory result = new Token[](tokenCount);

        if (tokenCount == 0) {
            return new Token[](0);
        } else {
            for (uint256 i = 0; i < tokenCount; i++) {
                result[i] = Token({
                    tokenId: tokenOfOwnerByIndex(_owner, i),
                    tokenURI: tokenURI(tokenOfOwnerByIndex(_owner, i))
                });
            }
            return result;
        }
    }

    // only operator //////////////////////////////////////////////////////////
    function getMintedBalance(address caller)
        external
        view
        onlyAuthorized
        returns (uint256)
    {
        return addressMintedBalance[caller];
    }

    function getTotalSupply() external view onlyAuthorized returns (uint256) {
        return totalSupply();
    }

    function getNonce(string memory _nonce)
        external
        view
        onlyAuthorized
        returns (bool)
    {
        return usedNonce[_nonce];
    }

    function setNonceUsed(string memory _nonce) external onlyAuthorized {
        usedNonce[_nonce] = true;
    }

    function getUsedUri(string memory _tokenUri)
        external
        view
        onlyAuthorized
        returns (bool)
    {
        return usedTokenURIs[_tokenUri] == 1;
    }

    function setUsedUri(string memory _tokenUri) external onlyAuthorized {
        usedTokenURIs[_tokenUri] = 1;
    }

    function setMinterContract(address _minter) external onlyOwner {
        minterContract = _minter;
    }

    function getMaxSupply() external view onlyAuthorized returns (uint256 max) {
        return MAX_SUPPLY;
    }

    // only owner functions
    function getMinterContract()
        external
        view
        onlyOwner
        returns (address minter)
    {
        return minterContract;
    }

    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }
}
