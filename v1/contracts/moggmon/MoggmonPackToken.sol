// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MoggmonPackToken
/// @dev VibeMarket-style ERC20 reserve used only for post-graduation crafting.
contract MoggmonPackToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;
    uint256 public constant SETUP_POOL_DENOMINATOR = 8;
    uint256 public constant TOTAL_FEE_BPS = 200;

    enum MarketType {
        PACK_MINT,
        CRAFTING
    }

    address public moggmonNftContract;
    address public factory;
    uint256 public totalSellOffers;
    uint256 public primaryMintTokenSupply;
    uint256 public contractReserveSupply;
    uint256 public setupPoolLimit;
    uint256 public setupPoolWithdrawn;
    MarketType public marketType;

    event MoggmonOfferMinted(address indexed recipient, uint256 amount);
    event MoggmonTokensSold(address indexed from, uint256 amount);
    event MoggmonMarketGraduated(address indexed nftAddress, address indexed tokenAddress);
    event MoggmonPoolSetup(
        address indexed recipient,
        uint256 amount,
        uint256 totalWithdrawn,
        uint256 limit
    );
    event MoggmonTokenFeesLocked(uint256 amount);
    event MoggmonTokenTransfer(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 balanceOfFrom,
        uint256 balanceOfTo,
        uint256 totalSupply
    );

    error NotDropContract();
    error AddressZero();
    error InsufficientLiquidity();
    error InvalidSupply();
    error MarketAlreadyGraduated();
    error MarketNotGraduated();
    error SetupPoolLimitExceeded();

    modifier onlyDropContract() {
        if (msg.sender != moggmonNftContract) revert NotDropContract();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address moggmonNftContract_,
        address factory_,
        uint256 primaryMintCap_,
        uint256 tokensPerMint_
    ) external initializer {
        if (owner_ == address(0)) revert AddressZero();
        if (moggmonNftContract_ == address(0)) revert AddressZero();
        if (factory_ == address(0)) revert AddressZero();
        if (primaryMintCap_ == 0 || tokensPerMint_ == 0) {
            revert InvalidSupply();
        }

        uint256 primaryMintTokenSupply_ = primaryMintCap_ * tokensPerMint_;
        if (primaryMintTokenSupply_ >= MAX_SUPPLY) revert InvalidSupply();

        __ERC20_init(tokenName_, tokenSymbol_);
        __Ownable_init(owner_);
        moggmonNftContract = moggmonNftContract_;
        factory = factory_;
        marketType = MarketType.PACK_MINT;
        primaryMintTokenSupply = primaryMintTokenSupply_;
        contractReserveSupply = MAX_SUPPLY;
        setupPoolLimit = primaryMintTokenSupply_ / SETUP_POOL_DENOMINATOR;

        _mint(address(this), MAX_SUPPLY);
    }

    function craftingActive() external view returns (bool) {
        return marketType == MarketType.CRAFTING;
    }

    function graduate() external onlyDropContract {
        _graduate();
    }

    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }

    function setupPool(
        address recipient,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert AddressZero();
        if (marketType != MarketType.CRAFTING) revert MarketNotGraduated();
        uint256 newSetupPoolWithdrawn = setupPoolWithdrawn + amount;
        if (newSetupPoolWithdrawn > setupPoolLimit) {
            revert SetupPoolLimitExceeded();
        }
        if (balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        setupPoolWithdrawn = newSetupPoolWithdrawn;
        _transfer(address(this), recipient, amount);

        emit MoggmonPoolSetup(recipient, amount, newSetupPoolWithdrawn, setupPoolLimit);
    }

    function sellTokens(
        address from,
        uint256 amount
    ) external onlyDropContract nonReentrant {
        if (from == address(0)) revert AddressZero();
        if (amount == 0) return;

        _transfer(from, address(this), amount);

        emit MoggmonTokensSold(from, amount);
    }

    function mintOffer(
        address recipient,
        uint256 amount
    ) external onlyDropContract nonReentrant {
        if (recipient == address(0)) revert AddressZero();
        if (amount == 0) return;
        if (balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        totalSellOffers += amount;
        _transfer(address(this), recipient, amount);

        emit MoggmonOfferMinted(recipient, amount);
    }

    function lockTokenFees(
        uint256 tokenAmount
    ) external onlyDropContract nonReentrant {
        if (tokenAmount == 0) return;

        _transfer(msg.sender, address(this), tokenAmount);

        emit MoggmonTokenFeesLocked(tokenAmount);
    }

    function _graduate() internal {
        if (marketType == MarketType.CRAFTING) revert MarketAlreadyGraduated();
        marketType = MarketType.CRAFTING;
        emit MoggmonMarketGraduated(moggmonNftContract, address(this));
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        super._update(from, to, value);

        emit MoggmonTokenTransfer(
            from,
            to,
            value,
            balanceOf(from),
            balanceOf(to),
            totalSupply()
        );
    }
}
