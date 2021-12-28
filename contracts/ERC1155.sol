// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract HotSwapNFTMarket is
    ReentrancyGuard,
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable
{
    string ipfsUri = "https://ipfs.infura.io/ipfs/{id}.json";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address payable marketplaceAddress) initializer {
        contractAddress = marketplaceAddress;
    }

    function initialize() public initializer {
        __ERC1155_init(ipfsUri);
        __Ownable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
    }

    using Counters for Counters.Counter;
    Counters.Counter private _collectionIds;
    Counters.Counter private _itemIds;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsForSale;
    Counters.Counter private _itemsSold;
    address payable contractAddress;
    uint256 listingPrice = 0.0025 ether;
    uint256 mintingPrice = 0.0001 ether;
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool forSale;
        bool sold;
    }
    struct Collection {
        uint256 collectionId;
        uint256 tokenId;
        address payable owner;
        uint256 collectionItemsSold;
        uint256[] collectionItems;
    }
    Collection[] public bars;

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Collection) private idToCollection;
    mapping(uint256 => string) private _uris;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed itemUri,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool forSale,
        bool sold
    );
    event CollectionCreated(
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address owner,
        uint256 collectionItemsSold,
        uint256[] collectionItems
    );

    function createMarketItem(
        address itemUri,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        uint256 itemPrice = 0;
        if (price > 0) {
            itemPrice = price;
        }

        idToMarketItem[itemId] = MarketItem(
            itemId,
            itemUri,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            false
        );

        safeTransferFrom(msg.sender, address(this), tokenId, 1, "");

        emit MarketItemCreated(
            itemId,
            itemUri,
            tokenId,
            msg.sender,
            address(0),
            price,
            false,
            false
        );
    }

    function createMarketCollection(string memory collectionUri)
        public
        payable
        nonReentrant
    {
        uint256 tokenId = mint(1, collectionUri, "");
        _collectionIds.increment();
        uint256 collectionId = _itemIds.current();

        idToCollection[collectionId] = Collection(
            collectionId,
            tokenId,
            payable(msg.sender),
            0,
            new uint256[](0)
        );

        safeTransferFrom(msg.sender, address(this), collectionId, 1, "");

        emit CollectionCreated(
            collectionId,
            tokenId,
            msg.sender,
            0,
            new uint256[](0)
        );
    }

    function addItemToCollection(uint256 collectionId, uint256 itemId)
        public
        onlyOwner
        nonReentrant
    {
        idToCollection[collectionId].collectionItems[itemId];
        require(
            idToCollection[collectionId].collectionItems[itemId] > 0,
            "Item already exists in collection"
        );

        idToCollection[collectionId].collectionItems.push(itemId);
    }

    function listItemForSale(uint256 itemId, uint256 price)
        public
        payable
        onlyOwner
        nonReentrant
    {
        bool forSaleStatus = idToMarketItem[itemId].forSale;
        require(forSaleStatus != true, "Item already for sale");
        require(price > 0, "Price must be at least 1wei");
        require(msg.value == listingPrice, "Fee must equal listing price");

        idToMarketItem[itemId].forSale = true;
        idToMarketItem[itemId].price = price;
        _itemsForSale.increment();
    }

    function removeSaleListing(uint256 itemId)
        public
        payable
        onlyOwner
        nonReentrant
    {
        bool forSaleStatus = idToMarketItem[itemId].forSale;
        require(forSaleStatus != false, "Item already NOT for sale");
        require(msg.value == listingPrice, "Fee must equal listing price");

        idToMarketItem[itemId].forSale = false;
        _itemsForSale.decrement();
    }

    function executeMarketSale(uint256 itemId) public payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(msg.value == price, "Asking price required");

        idToMarketItem[itemId].seller.transfer(msg.value);
        safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
        payable(contractAddress).transfer(listingPrice);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    function fetchMarketCollections()
        public
        view
        returns (Collection[] memory)
    {
        uint256 collectionCount = _collectionIds.current();
        Collection[] memory allCollections = new Collection[](collectionCount);
        for (uint256 i = 0; i < collectionCount; i++) {
            uint256 currentId = i + 1;
            Collection storage currentItem = idToCollection[currentId];
            allCollections[i] = currentItem;
        }
        return allCollections;
    }

    function fetchMyCollections() public view returns (Collection[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToCollection[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        Collection[] memory myCollections = new Collection[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToCollection[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                Collection storage currentItem = idToCollection[currentId];
                myCollections[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return myCollections;
    }

    function fetchMyItems() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToMarketItem[i + 1].seller == msg.sender ||
                idToMarketItem[i + 1].owner == msg.sender
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToMarketItem[i + 1].seller == msg.sender ||
                idToMarketItem[i + 1].owner == msg.sender
            ) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function uri(uint256 tokenId) public pure override returns (string memory) {
        return (
            string(
                abi.encodePacked("URL.com/", Strings.toString(tokenId), ".json")
            )
        );
    }

    function setURI(string memory newuri) public {
        ipfsUri = newuri;
        _setURI(newuri);
    }

    function setTokenURI(uint256 tokenId, string memory tokenUri)
        public
        onlyOwner
    {
        require(bytes(_uris[tokenId]).length == 0, "URI can only be set once");

        _uris[tokenId] = tokenUri;
    }

    function mint(
        uint256 amount,
        string memory tokenUri,
        bytes memory data
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId, amount, data);
        setTokenURI(newItemId, tokenUri);
        setApprovalForAll(contractAddress, true);
        return newItemId;
    }

    // function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    //     public
    // {
    //     _tokenIds.increment();
    //     uint256 newItemId = _tokenIds.current();
    //     _setTokenURI(newItemId, newuri);
    //     _mintBatch(to, ids, amounts, data);
    // }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
