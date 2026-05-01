// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {MoggmonPackToken} from "./MoggmonPackToken.sol";

library MoggmonVRFV2PlusClient {
    bytes4 internal constant EXTRA_ARGS_V1_TAG =
        bytes4(keccak256("VRF ExtraArgsV1"));

    struct ExtraArgsV1 {
        bool nativePayment;
    }

    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function _argsToBytes(
        ExtraArgsV1 memory extraArgs
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
    }
}

interface IMoggmonVRFCoordinatorV2Plus {
    function requestRandomWords(
        MoggmonVRFV2PlusClient.RandomWordsRequest calldata req
    ) external returns (uint256 requestId);
}

/// @title MoggmonPack
/// @dev ERC721 booster pack drop with Chainlink VRF reveals, SKU variants, and token crafting.
contract MoggmonPack is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 internal constant DEFAULT_TOKENS_PER_MINT = 100_000e18;
    uint256 internal constant DEFAULT_COMMON_OFFER = 20_000e18;
    uint256 internal constant DEFAULT_RARE_OFFER = 120_000e18;
    uint256 internal constant DEFAULT_EPIC_OFFER = 400_000e18;
    uint256 internal constant DEFAULT_LEGENDARY_OFFER = 1_500_000e18;
    uint256 internal constant DEFAULT_MYTHIC_OFFER = 2_000_000e18;
    uint256 public constant PACK_MINT_PRICE = 0.05 ether;
    uint256 public constant PRIMARY_MINT_CAP = 1_250;
    uint256 public constant ALLOWLIST_MINT_WINDOW = 3 hours;
    uint256 public constant INITIAL_CARD_SKU_COUNT = 151;
    uint256 internal constant INITIAL_COMMON_CARD_SKUS = 64;
    uint256 internal constant INITIAL_RARE_CARD_SKUS = 34;
    uint256 internal constant INITIAL_EPIC_CARD_SKUS = 35;
    uint256 internal constant INITIAL_LEGENDARY_CARD_SKUS = 8;
    uint256 internal constant INITIAL_MYTHIC_CARD_SKUS = 10;
    uint256 internal constant INITIAL_REGISTERED_SKU_COUNT =
        3 + (INITIAL_CARD_SKU_COUNT * 3);

    uint256 public COMMON_OFFER;
    uint256 public RARE_OFFER;
    uint256 public EPIC_OFFER;
    uint256 public LEGENDARY_OFFER;
    uint256 public MYTHIC_OFFER;

    uint8 public constant RARITY_COMMON = 1;
    uint8 public constant RARITY_RARE = 2;
    uint8 public constant RARITY_EPIC = 3;
    uint8 public constant RARITY_LEGENDARY = 4;
    uint8 public constant RARITY_MYTHIC = 5;
    uint256 public constant MAX_BATCH_SIZE = 25;
    uint256 public constant MAX_OPEN_BATCH_SIZE = 10;
    uint256 public constant MAX_REDEEM_BATCH_SIZE = 100;
    uint256 public constant TOTAL_ODDS = 1_000_000;
    uint256 public constant COMMON_THRESHOLD = 654_500;
    uint256 public constant RARE_THRESHOLD = 904_500;
    uint256 public constant EPIC_THRESHOLD = 994_500;
    uint256 public constant LEGENDARY_THRESHOLD = 999_500;
    uint256 public constant UNOPENED_OFFER_BPS = 10_000;

    uint256 public constant STANDARD_PACK_SKU_ID = 1;
    uint256 public constant HOLO_PACK_SKU_ID = 2;
    uint256 public constant PRISMATIC_PACK_SKU_ID = 3;
    uint256 public constant REVEALED_SKU_START_ID = 1_001;
    uint256 public constant SKU_BLOCK = 1_000_000;
    uint256 public constant PRISMATIC_SKU_THRESHOLD = 500;
    uint256 public constant HOLO_SKU_THRESHOLD = 30_000;
    uint256 public constant HOLO_PACK_REVEAL_ODDS_MULTIPLIER = 5;
    uint256 public constant PRISMATIC_PACK_REVEAL_ODDS_MULTIPLIER = 10;
    uint256 public constant MAX_METADATA_UPDATE_BATCH_SIZE = 25;
    uint256 internal constant RARITY_MAP_BITS = 3;
    uint256 internal constant RARITY_MAP_CHUNK_SIZE = 85;
    uint256 internal constant SKU_OFFSET_BITS = 8;
    uint8 public constant STANDARD_FOIL_VARIANT = 0;
    uint8 public constant HOLO_FOIL_VARIANT = 1;
    uint8 public constant PRISMATIC_FOIL_VARIANT = 2;
    uint32 public constant VRF_NUM_WORDS = 1;
    uint32 public constant DEFAULT_VRF_CALLBACK_GAS_LIMIT = 1_250_000;
    uint16 public constant DEFAULT_VRF_REQUEST_CONFIRMATIONS = 3;
    bytes4 internal constant SKU_METADATA_URI_SELECTOR =
        bytes4(keccak256("skuMetadataURI(uint256)"));
    bytes4 internal constant ERC4906_INTERFACE_ID = 0x49064906;
    uint256 internal constant VRF_RETRY_TIMEOUT = 2 minutes;

    // BEGIN GENERATED MOGGMON GEN1 MANIFEST
    // Generated from shared/moggmon/gen1-lab/catalog.json.
    // Run scripts/generate-moggmon-contract-manifest.mjs after catalog changes.
    uint256 internal constant RARITY_MAP_PACKED_0 =
        0x226965964b2c968b45930a2ca28a34b2514596592c945945145128948c462311;
    uint256 internal constant RARITY_MAP_PACKED_1 =
        0xdb52923ad92db25c2db69a65145a55325245965164b459a6d;
    uint256 internal constant COMMON_SKU_OFFSETS_0 =
        0x3c3b39373533312f2d2b2a28262422201f1d1c1a18161412100f0d0c09060300;
    uint256 internal constant COMMON_SKU_OFFSETS_1 =
        0x9689888483807775736c6b676563615f5e5b59575352504e4c4a49474544413e;
    uint256 internal constant COMMON_SKU_OFFSETS_2 =
        0x0;
    uint256 internal constant RARE_SKU_OFFSETS_0 =
        0x7b79767471706e6a6968625c54423f3834323029271b171513110e0b0a070401;
    uint256 internal constant RARE_SKU_OFFSETS_1 =
        0x9291;
    uint256 internal constant EPIC_SKU_OFFSETS_0 =
        0x878685827f7e7d7c7a78726d6664605d5a4f4d4b484643403d362c2523211e19;
    uint256 internal constant EPIC_SKU_OFFSETS_1 =
        0x8d8b8a;
    uint256 internal constant LEGENDARY_SKU_OFFSETS_0 =
        0x908f8e813a080502;
    uint256 internal constant MYTHIC_SKU_OFFSETS_0 =
        0x9594938c6f585655512e;
    // END GENERATED MOGGMON GEN1 MANIFEST

    struct Rarity {
        uint8 rarity;
        uint256 randomValue;
        bytes32 tokenSpecificRandomness;
    }

    struct InitializeParams {
        address owner;
        string nftName;
        string nftSymbol;
        address tokenAddress;
        address factory;
        string baseURI;
        address metadataFallbackContract;
        bytes32 merkleRoot;
        uint256 wlPacks;
        uint256 wlPacksPerAddress;
        bool allowlistNoTimeLimit;
    }

    struct MetadataURIUpdate {
        uint256 id;
        string uri;
    }

    address public moggmonTokenAddress;
    address public factory;
    address public metadataFallbackContract;
    string public baseURI;
    uint256 public tokensPerMint;
    uint256 public primaryIssuedCount;
    uint256 public issuedCount;
    uint256 public totalSupply;
    uint256 public unopenedSupply;
    bytes32 public merkleRoot;
    uint256 public wlPacks;
    uint256 public wlPacksPerAddress;
    uint256 public allowlistMinted;
    uint256 public allowlistStartTime;
    bool public allowlistNoTimeLimit;
    bool public startClaim;
    bool public craftRedemptionPaused;
    bool public holoCraftingEnabled;
    address public vrfCoordinator;
    uint256 public vrfSubscriptionId;
    bytes32 public vrfKeyHash;
    uint32 public vrfCallbackGasLimit;
    uint16 public vrfRequestConfirmations;
    bool public vrfNativePayment;

    mapping(uint256 => uint256) public tokenToBatchId;
    mapping(address => uint256) public wlMinted;
    mapping(uint256 => uint256) public vrfRequestToBatchId;
    mapping(uint256 => uint256) public batchVrfRequestId;
    mapping(uint256 => address) public batchOpener;
    mapping(uint256 => address) public batchVrfCoordinator;

    uint256 private _tokenIdCounter;
    mapping(uint256 => uint256) private _tokenUnits;
    mapping(uint256 => uint256) private _tokenSkuId;
    mapping(uint256 => string) private _skuMetadataURI;
    mapping(uint256 => uint256) private _totalSupplyBySku;
    mapping(address => mapping(uint256 => uint256)) private _ownerSkuBalance;
    mapping(uint256 => bytes32) private _tokenRandomness;
    mapping(uint256 => bytes32) private _batchRandomness;
    mapping(uint256 => uint256[]) private _batchTokenIds;
    mapping(address => mapping(uint256 => uint256))
        private _vrfRequestToBatchIdByCoordinator;
    mapping(uint256 => uint256) private _batchVrfRequestedAt;
    mapping(uint256 => bool) private _batchRandomnessFulfilled;
    uint256 private _nextBatchId;

    event MoggmonRandomnessFulfilled(uint256 indexed batchId, bytes32 randomNumber);
    event MoggmonRandomnessRequested(uint256 indexed batchId, uint256 indexed requestId);
    event MoggmonPrimaryRevenueWithdrawn(address indexed recipient, uint256 amount);
    event MoggmonPacksMinted(address indexed minter, uint256 amount, uint256 startTokenId, uint256 endTokenId);
    event MoggmonAssetTransfer(
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 skuId,
        uint256 currentSkuSupply,
        uint256 currentTotalSupply
    );
    event MoggmonCardRedeemed(address indexed burner, uint256 tokenId, uint8 rarity, uint256 offerAmount);
    event MoggmonCardsRedeemed(address indexed burner, uint256[] tokenIds, uint8[] rarities, uint256 finalOfferAmount);
    event MoggmonPackOpened(
        address indexed from,
        uint256[] tokenIds,
        uint256 batchId,
        uint64 sequenceNumber
    );
    event MoggmonCardRevealed(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed skuId,
        uint8 rarity,
        uint8 foilVariant,
        uint256 units,
        bytes32 randomNumber
    );
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event MoggmonRarityAssigned(uint256 batchId, bytes32 randomNumber);
    event MoggmonSkuRegistered(
        uint256 indexed skuId,
        uint8 indexed rarity,
        uint8 indexed foilVariant,
        uint256 baseSkuId,
        uint256 units
    );
    event MoggmonAllowlistConfigured(
        bytes32 merkleRoot,
        uint256 wlPacks,
        uint256 wlPacksPerAddress,
        bool allowlistNoTimeLimit
    );
    event MoggmonStartClaimToggled(bool enabled);
    event MoggmonCraftRedemptionPaused(bool paused);
    event MoggmonHoloCraftingToggled(bool enabled);
    event MoggmonSkuMetadataURIUpdated(uint256 indexed skuId, string uri);
    event MoggmonVrfConfigured(
        address indexed coordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        bool nativePayment
    );
    error MintAmountZero();
    error MintAmountTooHigh();
    error BatchEmpty();
    error BatchTooLarge();
    error InsufficientETHSent();
    error NotTokenOwner();
    error InvalidRarity();
    error InvalidConfiguration();
    error AddressZero();
    error TransferFailed();
    error RarityNotAssigned();
    error TokenAlreadyAssignedToBatch();
    error CannotSellOpenedPackBeforeRarityAssigned();
    error CraftingNotActive();
    error InvalidSku();
    error TokenDoesNotExist();
    error NotPack();
    error PrimaryMintEnded();
    error AllowlistDisabled();
    error AllowlistMintRequiresProof();
    error InvalidAllowlistConfiguration();
    error AllowlistConfigurationLocked();
    error InvalidProof();
    error InvalidAllowlistAllocation();
    error WLSupplyExceeded();
    error CraftRedemptionIsPaused();
    error WLLimitExceeded();
    error CannotRedeemPackForTokens();
    error VrfNotConfigured();
    error InvalidVrfConfiguration();
    error UnknownVrfRequest();
    error RandomnessAlreadyFulfilled();
    error RandomnessNotFulfilled();
    error PackRevealPending();
    error UnknownRevealBatch();
    error UnauthorizedRevealRetry();
    error VrfRetryUnavailable();
    error PublicMintDisabled();
    error ClaimNotStarted();
    error ClaimAlreadyStarted();
    error ClaimCannotBeStopped();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializeParams memory params) external initializer {
        if (params.owner == address(0)) revert AddressZero();
        if (params.tokenAddress == address(0)) revert AddressZero();
        if (params.factory == address(0)) revert AddressZero();

        __ERC721_init(params.nftName, params.nftSymbol);
        __Ownable_init(params.owner);
        moggmonTokenAddress = params.tokenAddress;
        factory = params.factory;
        baseURI = params.baseURI;
        if (
            params.metadataFallbackContract != address(0) &&
            params.metadataFallbackContract.code.length == 0
        ) {
            revert InvalidConfiguration();
        }
        metadataFallbackContract = params.metadataFallbackContract;
        tokensPerMint = DEFAULT_TOKENS_PER_MINT;

        COMMON_OFFER = DEFAULT_COMMON_OFFER;
        RARE_OFFER = DEFAULT_RARE_OFFER;
        EPIC_OFFER = DEFAULT_EPIC_OFFER;
        LEGENDARY_OFFER = DEFAULT_LEGENDARY_OFFER;
        MYTHIC_OFFER = DEFAULT_MYTHIC_OFFER;

        _nextBatchId = 1;
        vrfCallbackGasLimit = DEFAULT_VRF_CALLBACK_GAS_LIMIT;
        vrfRequestConfirmations = DEFAULT_VRF_REQUEST_CONFIRMATIONS;
        _registerPackSku(STANDARD_PACK_SKU_ID, STANDARD_FOIL_VARIANT);
        _registerPackSku(HOLO_PACK_SKU_ID, HOLO_FOIL_VARIANT);
        _registerPackSku(PRISMATIC_PACK_SKU_ID, PRISMATIC_FOIL_VARIANT);
        _emitInitialCardSkus();
        _configureAllowlist(
            params.merkleRoot,
            params.wlPacks,
            params.wlPacksPerAddress,
            params.allowlistNoTimeLimit
        );
        uint256 initialOwnerPacks = initialOwnerPackCount();
        if (initialOwnerPacks != 0) {
            _mintMoggmonPacks(params.owner, initialOwnerPacks, false);
        }
    }

    function configureAllowlist(
        bytes32 newMerkleRoot,
        uint256 newWlPacks,
        uint256 newWlPacksPerAddress,
        bool newAllowlistNoTimeLimit
    ) external onlyOwner {
        _configureAllowlist(
            newMerkleRoot,
            newWlPacks,
            newWlPacksPerAddress,
            newAllowlistNoTimeLimit
        );
    }

    function configureVrf(
        address coordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        bool nativePayment
    ) external onlyOwner {
        _configureVrf(
            coordinator,
            subscriptionId,
            keyHash,
            callbackGasLimit,
            requestConfirmations,
            nativePayment
        );
    }

    function pauseCraft(bool paused) external onlyOwner {
        craftRedemptionPaused = paused;
        emit MoggmonCraftRedemptionPaused(paused);
    }

    function startClaims() external onlyOwner {
        _startClaims();
    }

    function toggleStartClaim(bool enabled) external onlyOwner {
        if (!enabled) revert ClaimCannotBeStopped();
        _startClaims();
    }

    function toggleHoloCrafting(bool enabled) external onlyOwner {
        holoCraftingEnabled = enabled;
        emit MoggmonHoloCraftingToggled(enabled);
    }

    function renounceOwnership() public override onlyOwner {
        craftRedemptionPaused = true;
        holoCraftingEnabled = false;
        emit MoggmonCraftRedemptionPaused(true);
        emit MoggmonHoloCraftingToggled(false);
        super.renounceOwnership();
    }

    function registeredSkuCount() external pure returns (uint256) {
        return INITIAL_REGISTERED_SKU_COUNT;
    }

    function registeredSkuIdAt(uint256 index) external pure returns (uint256) {
        if (index < 3) return index + 1;
        if (index < INITIAL_REGISTERED_SKU_COUNT) {
            return _skuIdFromBaseAndVariant(
                REVEALED_SKU_START_ID + ((index - 3) / 3),
                uint8((index - 3) % 3)
            );
        }

        revert InvalidSku();
    }

    function totalSupplyBySku(uint256 skuId) external view returns (uint256) {
        return _totalSupplyBySku[skuId];
    }

    function balanceOfSku(
        address owner,
        uint256 skuId
    ) external view returns (uint256) {
        return _ownerSkuBalance[owner][skuId];
    }

    function balanceOfSkus(
        address owner,
        uint256[] calldata skuIds
    ) external view returns (uint256[] memory balances) {
        balances = new uint256[](skuIds.length);
        for (uint256 i = 0; i < skuIds.length; ) {
            balances[i] = _ownerSkuBalance[owner][skuIds[i]];
            unchecked {
                ++i;
            }
        }
    }

    function batchRandomness(uint256 batchId) external view returns (bytes32) {
        if (!_batchRandomnessFulfilled[batchId]) revert RandomnessNotFulfilled();
        return _batchRandomness[batchId];
    }

    function openFeePerBatch() public pure returns (uint256) {
        return 0;
    }

    function unitsBySku(uint256 skuId) public view returns (uint256) {
        if (_isPackSku(skuId)) return tokensPerMint;
        uint8 rarity = rarityBySku(skuId);
        if (rarity == 0) return 0;
        return _unitsForRarity(rarity);
    }

    function rarityBySku(uint256 skuId) public pure returns (uint8) {
        if (_isPackSku(skuId)) return 0;
        (uint256 baseSkuId, , bool valid) = _decodeSkuId(skuId);
        if (!valid) return 0;
        return _rarityByBaseSku(baseSkuId);
    }

    function foilVariantBySku(uint256 skuId) public pure returns (uint8) {
        if (skuId == STANDARD_PACK_SKU_ID) return STANDARD_FOIL_VARIANT;
        if (skuId == HOLO_PACK_SKU_ID) return HOLO_FOIL_VARIANT;
        if (skuId == PRISMATIC_PACK_SKU_ID) return PRISMATIC_FOIL_VARIANT;

        (, uint8 foilVariant, bool valid) = _decodeSkuId(skuId);
        if (!valid) return 0;
        return foilVariant;
    }

    function baseSkuIdBySku(uint256 skuId) public pure returns (uint256) {
        if (_isPackSku(skuId)) return skuId;

        (uint256 baseSkuId, , bool valid) = _decodeSkuId(skuId);
        if (!valid) return 0;
        return baseSkuId;
    }

    function tokenSkuId(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _tokenSkuId[tokenId];
    }

    function tokenUnits(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _tokenUnits[tokenId];
    }

    function skuMetadataURI(uint256 skuId) public view returns (string memory) {
        string memory exactSkuURI = _skuMetadataURI[skuId];
        if (bytes(exactSkuURI).length > 0) return exactSkuURI;

        uint256 baseSkuId = _metadataBaseSkuId(skuId);
        if (baseSkuId != 0 && baseSkuId != skuId) {
            string memory baseSkuURI = _skuMetadataURI[baseSkuId];
            if (bytes(baseSkuURI).length > 0) return baseSkuURI;
        }

        string memory fallbackSkuURI = _readMetadataFallbackURI(skuId);
        if (bytes(fallbackSkuURI).length > 0) return fallbackSkuURI;

        if (baseSkuId != 0 && baseSkuId != skuId) {
            string memory fallbackBaseSkuURI = _readMetadataFallbackURI(
                baseSkuId
            );
            if (bytes(fallbackBaseSkuURI).length > 0) {
                return fallbackBaseSkuURI;
            }
        }

        return "";
    }

    function updateSkuMetadata(
        MetadataURIUpdate[] calldata updates
    ) external onlyOwner {
        _requireMetadataUpdateBatch(updates.length);

        for (uint256 i = 0; i < updates.length; ) {
            uint256 skuId = updates[i].id;
            string calldata uri = updates[i].uri;
            if (bytes(uri).length == 0) revert InvalidConfiguration();
            if (!_isValidMetadataSku(skuId)) revert InvalidSku();

            _skuMetadataURI[skuId] = uri;
            emit MoggmonSkuMetadataURIUpdated(skuId, uri);

            unchecked {
                ++i;
            }
        }

        _emitAllTokenMetadataUpdateIfAny();
    }

    function open(uint256[] memory tokenIds) external payable nonReentrant {
        if (tokenIds.length == 0) revert BatchEmpty();
        if (tokenIds.length > MAX_OPEN_BATCH_SIZE) revert BatchTooLarge();

        if (msg.value != 0) revert InsufficientETHSent();

        uint256 pendingBatchId = tokenToBatchId[tokenIds[0]];
        if (pendingBatchId != 0 && !_batchRandomnessFulfilled[pendingBatchId]) {
            if (tokenIds.length != 1) revert BatchTooLarge();
            _retryRevealRandomness(pendingBatchId);
            return;
        }

        uint256 batchId = _nextBatchId++;
        uint64 sequenceNumber = uint64(batchId);
        _mapTokensToBatch(tokenIds, batchId, msg.sender);
        batchOpener[batchId] = msg.sender;

        emit MoggmonPackOpened(msg.sender, tokenIds, batchId, sequenceNumber);

        _requestRevealRandomness(batchId);
    }

    function retryRevealRandomness(
        uint256 batchId
    ) external nonReentrant returns (uint256 requestId) {
        requestId = _retryRevealRandomness(batchId);
    }

    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external {
        uint256 batchId = _vrfRequestToBatchIdByCoordinator[msg.sender][
            requestId
        ];
        if (batchId == 0) revert UnknownVrfRequest();
        if (_batchRandomnessFulfilled[batchId]) revert RandomnessAlreadyFulfilled();
        if (randomWords.length == 0) revert InvalidVrfConfiguration();

        bytes32 randomNumber = bytes32(randomWords[0]);
        _batchRandomness[batchId] = randomNumber;
        _batchRandomnessFulfilled[batchId] = true;
        _finalizeOpenedBatch(batchId);

        emit MoggmonRandomnessFulfilled(batchId, randomNumber);
        emit MoggmonRarityAssigned(batchId, randomNumber);
    }

    function mint(uint256 amount) external payable nonReentrant {
        _mintWithEth(amount, msg.sender, address(0), address(0), false);
    }

    function mint(
        uint256 amount,
        address recipient,
        address referrer,
        address originReferrer
    ) external payable nonReentrant {
        _mintWithEth(amount, recipient, referrer, originReferrer, false);
    }

    function mintAllowlistWithAllocation(
        uint256 amount,
        uint256 allocation,
        bytes32[] calldata proof
    ) external payable nonReentrant {
        _consumeAllowlistWithAllocation(msg.sender, amount, allocation, proof);
        _mintWithEth(amount, msg.sender, address(0), address(0), true);
    }

    function mintAllowlistWithAllocationFor(
        uint256 amount,
        address recipient,
        uint256 allocation,
        bytes32[] calldata proof
    ) external payable nonReentrant {
        _consumeAllowlistWithAllocation(recipient, amount, allocation, proof);
        _mintWithEth(amount, recipient, address(0), address(0), true);
    }

    function mintWithToken(uint256 amount) external nonReentrant {
        if (!_craftingActive()) revert CraftingNotActive();
        if (amount == 0) revert MintAmountZero();
        if (amount > MAX_BATCH_SIZE) revert MintAmountTooHigh();

        uint256 tokensNeeded = amount * tokensPerMint;
        MoggmonPackToken(payable(moggmonTokenAddress)).sellTokens(
            msg.sender,
            tokensNeeded
        );

        _mintMoggmonPacks(msg.sender, amount, holoCraftingEnabled);
    }

    function getMintPrice(uint256 amount) public pure returns (uint256) {
        return amount * PACK_MINT_PRICE;
    }

    function primaryMintCap() public pure virtual returns (uint256) {
        return PRIMARY_MINT_CAP;
    }

    function allowlistMintActive() public view returns (bool) {
        bool craftingActive = _craftingActive();
        if (
            merkleRoot == bytes32(0) ||
            wlPacks == 0 ||
            wlPacksPerAddress == 0 ||
            allowlistMinted >= wlPacks ||
            primaryIssuedCount >= primaryMintCap() ||
            (craftingActive && !_allowAllowlistMintDuringCrafting())
        ) {
            return false;
        }
        if (allowlistNoTimeLimit) {
            return true;
        }
        return block.timestamp < allowlistStartTime + ALLOWLIST_MINT_WINDOW;
    }

    function getTokenRarity(
        uint256 tokenId
    ) public view returns (Rarity memory rarityInfo) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        uint256 skuId = _tokenSkuId[tokenId];
        if (skuId < REVEALED_SKU_START_ID) {
            revert RarityNotAssigned();
        }
        bytes32 tokenRandom = _tokenRandomness[tokenId];
        return
            Rarity({
                rarity: rarityBySku(skuId),
                randomValue: uint256(tokenRandom) % TOTAL_ODDS,
                tokenSpecificRandomness: tokenRandom
            });
    }

    function sellAndClaimOffer(
        uint256 tokenId
    ) external nonReentrant returns (uint256) {
        if (!_craftingActive()) revert CraftingNotActive();
        if (craftRedemptionPaused) revert CraftRedemptionIsPaused();

        (uint256 offerAmount, uint8 rarity) = _sellAndClaimOffer(
            tokenId,
            msg.sender,
            address(this)
        );
        uint256 feeAmount = (offerAmount *
            MoggmonPackToken(payable(moggmonTokenAddress)).TOTAL_FEE_BPS()) /
            10_000;
        uint256 finalOfferAmount = offerAmount - feeAmount;

        IERC20(moggmonTokenAddress).safeTransfer(msg.sender, finalOfferAmount);
        MoggmonPackToken(payable(moggmonTokenAddress)).lockTokenFees(
            feeAmount
        );

        emit MoggmonCardRedeemed(msg.sender, tokenId, rarity, finalOfferAmount);

        return finalOfferAmount;
    }

    function sellAndClaimOfferBatch(
        uint256[] memory tokenIds
    ) external nonReentrant returns (uint256) {
        if (!_craftingActive()) revert CraftingNotActive();
        if (craftRedemptionPaused) revert CraftRedemptionIsPaused();

        (uint256 totalOfferAmount, uint8[] memory rarities) = _sellAndClaimOfferBatch(
            tokenIds,
            msg.sender,
            address(this)
        );
        uint256 feeAmount = (totalOfferAmount *
            MoggmonPackToken(payable(moggmonTokenAddress)).TOTAL_FEE_BPS()) /
            10_000;
        uint256 finalOfferAmount = totalOfferAmount - feeAmount;

        IERC20(moggmonTokenAddress).safeTransfer(msg.sender, finalOfferAmount);
        MoggmonPackToken(payable(moggmonTokenAddress)).lockTokenFees(
            feeAmount
        );

        emit MoggmonCardsRedeemed(msg.sender, tokenIds, rarities, finalOfferAmount);

        return finalOfferAmount;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();

        uint256 metadataSkuId = _metadataSkuIdForToken(tokenId);
        if (metadataSkuId != 0) {
            string memory skuURI = skuMetadataURI(metadataSkuId);
            if (bytes(skuURI).length > 0) return skuURI;
        }

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == ERC4906_INTERFACE_ID ||
            super.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return baseURI;
    }

    function updateBaseURI(string calldata newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) revert InvalidConfiguration();
        baseURI = newBaseURI;
        _emitAllTokenMetadataUpdateIfAny();
    }

    function activateInitialCrafting() external {
        if (_initialCraftingActive() && !_craftingActive()) {
            MoggmonPackToken(payable(moggmonTokenAddress)).graduate();
        }
    }

    function withdrawPrimaryRevenue(
        address payable recipient,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert AddressZero();
        uint256 balance = address(this).balance;
        if (amount > balance) revert InsufficientETHSent();

        _sendETH(recipient, amount);

        emit MoggmonPrimaryRevenueWithdrawn(recipient, amount);
    }

    function _mintWithEth(
        uint256 amount,
        address recipient,
        address,
        address,
        bool allowlistMint
    ) internal {
        if (amount == 0) revert MintAmountZero();
        if (amount > MAX_BATCH_SIZE) revert MintAmountTooHigh();
        if (recipient == address(0)) revert AddressZero();
        if (!allowlistMint && !_publicMintEnabled()) {
            revert PublicMintDisabled();
        }
        bool craftingActive = _craftingActive();
        if (
            craftingActive &&
            (!allowlistMint || !_allowAllowlistMintDuringCrafting())
        ) {
            revert PrimaryMintEnded();
        }
        if (!allowlistMint && allowlistMintActive()) {
            revert AllowlistMintRequiresProof();
        }

        uint256 mintPrice = allowlistMint ? 0 : getMintPrice(amount);
        if (msg.value < mintPrice) revert InsufficientETHSent();

        uint256 newPrimaryIssuedCount = primaryIssuedCount + amount;
        if (newPrimaryIssuedCount > primaryMintCap()) revert PrimaryMintEnded();
        primaryIssuedCount = newPrimaryIssuedCount;

        _mintMoggmonPacks(recipient, amount, false);

        if (newPrimaryIssuedCount == primaryMintCap() && !craftingActive) {
            MoggmonPackToken(payable(moggmonTokenAddress)).graduate();
        }

        uint256 refund = msg.value - mintPrice;
        _refundExcessETH(payable(msg.sender), refund);
    }

    function _configureAllowlist(
        bytes32 newMerkleRoot,
        uint256 newWlPacks,
        uint256 newWlPacksPerAddress,
        bool newAllowlistNoTimeLimit
    ) internal {
        if (primaryIssuedCount != 0) revert AllowlistConfigurationLocked();
        if (allowlistMinted != 0) revert AllowlistConfigurationLocked();

        bool disabled = newMerkleRoot == bytes32(0) &&
            newWlPacks == 0 &&
            newWlPacksPerAddress == 0;
        if (
            _requiresFullAllowlistAllocation() &&
            (disabled ||
                newWlPacks != primaryMintCap() ||
                !newAllowlistNoTimeLimit)
        ) {
            revert InvalidAllowlistConfiguration();
        }
        if (!disabled) {
            if (
                newMerkleRoot == bytes32(0) ||
                newWlPacks == 0 ||
                newWlPacksPerAddress == 0 ||
                newWlPacks > primaryMintCap() ||
                newWlPacksPerAddress > newWlPacks
            ) {
                revert InvalidAllowlistConfiguration();
            }
        }

        merkleRoot = newMerkleRoot;
        wlPacks = newWlPacks;
        wlPacksPerAddress = newWlPacksPerAddress;
        allowlistNoTimeLimit = disabled ? false : newAllowlistNoTimeLimit;
        allowlistStartTime = disabled ? 0 : block.timestamp;

        emit MoggmonAllowlistConfigured(
            merkleRoot,
            wlPacks,
            wlPacksPerAddress,
            allowlistNoTimeLimit
        );
    }

    function _configureVrf(
        address coordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        bool nativePayment
    ) internal {
        if (
            coordinator == address(0) ||
            subscriptionId == 0 ||
            keyHash == bytes32(0) ||
            callbackGasLimit == 0 ||
            requestConfirmations == 0
        ) {
            revert InvalidVrfConfiguration();
        }

        vrfCoordinator = coordinator;
        vrfSubscriptionId = subscriptionId;
        vrfKeyHash = keyHash;
        vrfCallbackGasLimit = callbackGasLimit;
        vrfRequestConfirmations = requestConfirmations;
        vrfNativePayment = nativePayment;

        emit MoggmonVrfConfigured(
            coordinator,
            subscriptionId,
            keyHash,
            callbackGasLimit,
            requestConfirmations,
            nativePayment
        );
    }

    function _retryRevealRandomness(
        uint256 batchId
    ) internal returns (uint256 requestId) {
        address opener = batchOpener[batchId];
        if (opener == address(0)) revert UnknownRevealBatch();
        if (msg.sender != opener && msg.sender != owner()) {
            revert UnauthorizedRevealRetry();
        }
        if (_batchRandomnessFulfilled[batchId]) {
            revert RandomnessAlreadyFulfilled();
        }

        uint256 requestedAt = _batchVrfRequestedAt[batchId];
        if (requestedAt == 0) revert UnknownRevealBatch();
        if (block.timestamp < requestedAt + VRF_RETRY_TIMEOUT) {
            revert VrfRetryUnavailable();
        }

        requestId = _requestRevealRandomness(batchId);
    }

    function _requestRevealRandomness(
        uint256 batchId
    ) internal returns (uint256 requestId) {
        if (
            vrfCoordinator == address(0) ||
            vrfSubscriptionId == 0 ||
            vrfKeyHash == bytes32(0)
        ) {
            revert VrfNotConfigured();
        }

        requestId = IMoggmonVRFCoordinatorV2Plus(vrfCoordinator)
            .requestRandomWords(
                MoggmonVRFV2PlusClient.RandomWordsRequest({
                    keyHash: vrfKeyHash,
                    subId: vrfSubscriptionId,
                    requestConfirmations: vrfRequestConfirmations,
                    callbackGasLimit: vrfCallbackGasLimit,
                    numWords: VRF_NUM_WORDS,
                    extraArgs: MoggmonVRFV2PlusClient._argsToBytes(
                        MoggmonVRFV2PlusClient.ExtraArgsV1({
                            nativePayment: vrfNativePayment
                        })
                    )
                })
            );
        if (requestId == 0) revert InvalidVrfConfiguration();

        vrfRequestToBatchId[requestId] = batchId;
        batchVrfRequestId[batchId] = requestId;
        _batchVrfRequestedAt[batchId] = block.timestamp;
        batchVrfCoordinator[batchId] = vrfCoordinator;
        _vrfRequestToBatchIdByCoordinator[vrfCoordinator][requestId] = batchId;

        emit MoggmonRandomnessRequested(batchId, requestId);
    }

    function _consumeAllowlistWithAllocation(
        address buyer,
        uint256 amount,
        uint256 allocation,
        bytes32[] calldata proof
    ) internal {
        if (allocation == 0 || allocation > wlPacksPerAddress) {
            revert InvalidAllowlistAllocation();
        }
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(buyer, allocation)))
        );
        _consumeAllowlist(buyer, amount, allocation, leaf, proof);
    }

    function _consumeAllowlist(
        address buyer,
        uint256 amount,
        uint256 walletLimit,
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal {
        if (!startClaim) revert ClaimNotStarted();
        if (!allowlistMintActive()) revert AllowlistDisabled();
        if (allowlistMinted + amount > wlPacks) revert WLSupplyExceeded();
        if (wlMinted[buyer] + amount > walletLimit) {
            revert WLLimitExceeded();
        }

        if (!MerkleProof.verifyCalldata(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        allowlistMinted += amount;
        wlMinted[buyer] += amount;
    }

    function _startClaims() internal {
        if (startClaim) revert ClaimAlreadyStarted();
        startClaim = true;
        emit MoggmonStartClaimToggled(true);
    }

    function _mintMoggmonPacks(
        address recipient,
        uint256 amount,
        bool allowPackFoils
    ) internal {
        uint256 startingTokenId = _tokenIdCounter + 1;
        for (uint256 i = 0; i < amount; ) {
            _tokenIdCounter++;
            uint256 tokenId = _tokenIdCounter;
            uint256 skuId = _mintPackSkuId(
                recipient,
                tokenId,
                allowPackFoils
            );

            _tokenSkuId[tokenId] = skuId;
            _tokenUnits[tokenId] = tokensPerMint;
            _totalSupplyBySku[skuId] += 1;
            issuedCount += 1;
            totalSupply += 1;
            unopenedSupply += 1;

            _mint(recipient, tokenId);

            unchecked {
                ++i;
            }
        }

        emit MoggmonPacksMinted(
            recipient,
            amount,
            startingTokenId,
            _tokenIdCounter
        );
    }

    function _sellAndClaimOffer(
        uint256 tokenId,
        address seller,
        address recipient
    ) internal returns (uint256, uint8) {
        if (ownerOf(tokenId) != seller) revert NotTokenOwner();

        (uint256 offerAmount, uint8 rarity) = _getTokenOfferAmount(tokenId);
        if (tokenToBatchId[tokenId] != 0 && rarity == 0) {
            revert CannotSellOpenedPackBeforeRarityAssigned();
        }

        _burnRedeemedToken(tokenId);
        MoggmonPackToken(payable(moggmonTokenAddress)).mintOffer(
            recipient,
            offerAmount
        );

        return (offerAmount, rarity);
    }

    function _sellAndClaimOfferBatch(
        uint256[] memory tokenIds,
        address seller,
        address recipient
    ) internal returns (uint256, uint8[] memory) {
        if (tokenIds.length == 0) revert BatchEmpty();
        if (tokenIds.length > MAX_REDEEM_BATCH_SIZE) revert BatchTooLarge();

        uint256 totalOfferAmount;
        uint8[] memory rarities = new uint8[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; ) {
            if (ownerOf(tokenIds[i]) != seller) revert NotTokenOwner();

            (uint256 offerAmount, uint8 rarity) = _getTokenOfferAmount(
                tokenIds[i]
            );
            if (tokenToBatchId[tokenIds[i]] != 0 && rarity == 0) {
                revert CannotSellOpenedPackBeforeRarityAssigned();
            }

            totalOfferAmount += offerAmount;
            rarities[i] = rarity;
            _burnRedeemedToken(tokenIds[i]);

            unchecked {
                ++i;
            }
        }

        MoggmonPackToken(payable(moggmonTokenAddress)).mintOffer(
            recipient,
            totalOfferAmount
        );

        return (totalOfferAmount, rarities);
    }

    function _burnRedeemedToken(uint256 tokenId) internal {
        uint256 skuId = _tokenSkuId[tokenId];
        _totalSupplyBySku[skuId] -= 1;
        totalSupply -= 1;
        _burn(tokenId);
        delete _tokenSkuId[tokenId];
        delete _tokenUnits[tokenId];
        delete _tokenRandomness[tokenId];
        delete tokenToBatchId[tokenId];
    }

    function _getTokenOfferAmount(
        uint256 tokenId
    ) internal view returns (uint256, uint8) {
        uint256 skuId = _tokenSkuId[tokenId];
        if (skuId < REVEALED_SKU_START_ID) {
            revert CannotRedeemPackForTokens();
        }

        uint256 offerAmount = unitsBySku(skuId);
        if (offerAmount == 0) revert InvalidSku();
        return (offerAmount, rarityBySku(skuId));
    }

    function _mapTokensToBatch(
        uint256[] memory tokenIds,
        uint256 batchId,
        address sender
    ) internal {
        uint256[] storage storedTokenIds = _batchTokenIds[batchId];
        if (storedTokenIds.length != 0) revert TokenAlreadyAssignedToBatch();

        for (uint256 i = 0; i < tokenIds.length; ) {
            uint256 tokenId = tokenIds[i];
            if (tokenToBatchId[tokenId] != 0) revert TokenAlreadyAssignedToBatch();
            if (ownerOf(tokenId) != sender) revert NotTokenOwner();
            if (_tokenSkuId[tokenId] >= REVEALED_SKU_START_ID) revert NotPack();

            tokenToBatchId[tokenId] = batchId;
            storedTokenIds.push(tokenId);

            unchecked {
                ++i;
            }
        }
    }

    function _finalizeOpenedBatch(uint256 batchId) internal {
        uint256[] storage tokenIds = _batchTokenIds[batchId];
        uint256 tokenCount = tokenIds.length;
        if (tokenCount == 0) revert BatchEmpty();

        address opener = batchOpener[batchId];
        bytes32 batchRandom = _batchRandomness[batchId];

        unopenedSupply -= tokenCount;

        for (uint256 i = 0; i < tokenCount; ) {
            uint256 tokenId = tokenIds[i];
            uint256 packSkuId = _tokenSkuId[tokenId];
            if (!_isPackSku(packSkuId)) revert NotPack();

            bytes32 tokenRandom = keccak256(
                abi.encodePacked(batchRandom, tokenId)
            );
            (uint8 rarity, uint256 units, uint256 revealedSkuId) = _resolveRevealSkuId(
                packSkuId,
                tokenRandom
            );

            _totalSupplyBySku[packSkuId] -= 1;
            _ownerSkuBalance[opener][packSkuId] -= 1;
            _tokenSkuId[tokenId] = revealedSkuId;
            _tokenUnits[tokenId] = units;
            _tokenRandomness[tokenId] = tokenRandom;
            _totalSupplyBySku[revealedSkuId] += 1;
            _ownerSkuBalance[opener][revealedSkuId] += 1;

            emit MoggmonCardRevealed(
                opener,
                tokenId,
                revealedSkuId,
                rarity,
                foilVariantBySku(revealedSkuId),
                units,
                tokenRandom
            );

            unchecked {
                ++i;
            }
        }

        _emitAllTokenMetadataUpdateIfAny();
    }

    function _resolveRevealSkuId(
        uint256 unopenedPackSkuId,
        bytes32 tokenRandom
    ) internal view returns (uint8 rarity, uint256 units, uint256 skuId) {
        rarity = _rarityFromRandom(tokenRandom);
        units = _unitsForRarity(rarity);
        uint256 baseSkuId = _selectRevealSkuId(rarity, tokenRandom);
        uint8 foilVariant = _foilVariantFromRandom(tokenRandom, unopenedPackSkuId);
        skuId = _composeRevealSkuId(baseSkuId, foilVariant);
        if (unitsBySku(skuId) == 0) revert InvalidSku();
    }

    function _selectRevealSkuId(
        uint8 rarity,
        bytes32 tokenRandom
    ) internal pure returns (uint256) {
        uint256 fixedSkuCount = _fixedBaseSkuCountForRarity(rarity);
        if (fixedSkuCount == 0) revert InvalidRarity();

        uint256 index = uint256(
            keccak256(abi.encodePacked(tokenRandom, "registered_sku"))
        ) % fixedSkuCount;
        return _fixedBaseSkuIdByRarityIndex(rarity, index);
    }

    function _mintPackSkuId(
        address recipient,
        uint256 tokenId,
        bool allowPackFoils
    ) internal view returns (uint256) {
        if (!allowPackFoils) return STANDARD_PACK_SKU_ID;

        bytes32 tokenRandom = keccak256(
            abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                blockhash(block.number - 1),
                recipient,
                tokenId,
                address(this)
            )
        );
        uint8 foilVariant = _packFoilVariantFromRandom(tokenRandom);
        if (foilVariant == PRISMATIC_FOIL_VARIANT) return PRISMATIC_PACK_SKU_ID;
        if (foilVariant == HOLO_FOIL_VARIANT) return HOLO_PACK_SKU_ID;
        return STANDARD_PACK_SKU_ID;
    }

    function _packFoilVariantFromRandom(
        bytes32 tokenRandom
    ) internal pure returns (uint8) {
        return
            _foilVariantFromRandom(
                tokenRandom,
                STANDARD_PACK_SKU_ID,
                PRISMATIC_SKU_THRESHOLD,
                HOLO_SKU_THRESHOLD
            );
    }

    function _foilVariantFromRandom(
        bytes32 tokenRandom,
        uint256 unopenedPackSkuId
    ) internal pure returns (uint8) {
        return
            _foilVariantFromRandom(
                tokenRandom,
                unopenedPackSkuId,
                PRISMATIC_SKU_THRESHOLD,
                HOLO_SKU_THRESHOLD
            );
    }

    function _foilVariantFromRandom(
        bytes32 tokenRandom,
        uint256 unopenedPackSkuId,
        uint256 prismaticThresholdBase,
        uint256 holoThresholdBase
    ) internal pure returns (uint8) {
        uint256 oddsMultiplier = STANDARD_PACK_SKU_ID;
        if (unopenedPackSkuId == HOLO_PACK_SKU_ID) {
            oddsMultiplier = HOLO_PACK_REVEAL_ODDS_MULTIPLIER;
        } else if (unopenedPackSkuId == PRISMATIC_PACK_SKU_ID) {
            oddsMultiplier = PRISMATIC_PACK_REVEAL_ODDS_MULTIPLIER;
        }

        uint256 roll = uint256(
            keccak256(abi.encodePacked(tokenRandom, "foil_roll"))
        ) % TOTAL_ODDS;
        if (roll < prismaticThresholdBase * oddsMultiplier) {
            return PRISMATIC_FOIL_VARIANT;
        }
        if (roll < holoThresholdBase * oddsMultiplier) {
            return HOLO_FOIL_VARIANT;
        }
        return STANDARD_FOIL_VARIANT;
    }

    function _rarityFromRandom(bytes32 randomNumber) internal pure returns (uint8) {
        uint256 roll = uint256(randomNumber) % TOTAL_ODDS;
        if (roll < COMMON_THRESHOLD) return RARITY_COMMON;
        if (roll < RARE_THRESHOLD) return RARITY_RARE;
        if (roll < EPIC_THRESHOLD) return RARITY_EPIC;
        if (roll < LEGENDARY_THRESHOLD) return RARITY_LEGENDARY;
        return RARITY_MYTHIC;
    }

    function _unitsForRarity(uint8 rarity) internal view returns (uint256) {
        if (rarity == RARITY_COMMON) return COMMON_OFFER;
        if (rarity == RARITY_RARE) return RARE_OFFER;
        if (rarity == RARITY_EPIC) return EPIC_OFFER;
        if (rarity == RARITY_LEGENDARY) return LEGENDARY_OFFER;
        if (rarity == RARITY_MYTHIC) return MYTHIC_OFFER;
        revert InvalidRarity();
    }

    function _emitInitialCardSkus() internal {
        for (uint256 i = 0; i < INITIAL_CARD_SKU_COUNT; ) {
            uint256 baseSkuId = REVEALED_SKU_START_ID + i;
            uint8 rarity = _fixedRarityByBaseSku(baseSkuId);
            uint256 units = _unitsForRarity(rarity);
            _emitSkuSetRegistered(baseSkuId, rarity, units);
            unchecked {
                ++i;
            }
        }
    }

    function _registerPackSku(uint256 skuId, uint8 foilVariant) internal {
        emit MoggmonSkuRegistered(skuId, 0, foilVariant, skuId, tokensPerMint);
    }

    function _emitSkuSetRegistered(
        uint256 baseSkuId,
        uint8 rarity,
        uint256 units
    ) internal {
        emit MoggmonSkuRegistered(
            baseSkuId,
            rarity,
            STANDARD_FOIL_VARIANT,
            baseSkuId,
            units
        );
        emit MoggmonSkuRegistered(
            _composeRevealSkuId(baseSkuId, HOLO_FOIL_VARIANT),
            rarity,
            HOLO_FOIL_VARIANT,
            baseSkuId,
            units
        );
        emit MoggmonSkuRegistered(
            _composeRevealSkuId(baseSkuId, PRISMATIC_FOIL_VARIANT),
            rarity,
            PRISMATIC_FOIL_VARIANT,
            baseSkuId,
            units
        );
    }

    function _readMetadataFallbackURI(
        uint256 skuId
    ) internal view returns (string memory) {
        address fallbackContract = metadataFallbackContract;
        if (fallbackContract == address(0)) return "";

        (bool success, bytes memory data) = fallbackContract.staticcall(
            abi.encodeWithSelector(SKU_METADATA_URI_SELECTOR, skuId)
        );
        if (!success || data.length < 64) return "";

        return abi.decode(data, (string));
    }

    function _refundExcessETH(address payable recipient, uint256 amount) internal {
        if (amount == 0) return;
        _sendETH(recipient, amount);
    }

    function _sendETH(address payable recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function _composeRevealSkuId(
        uint256 baseSkuId,
        uint8 foilVariant
    ) internal pure returns (uint256) {
        if (foilVariant == STANDARD_FOIL_VARIANT) return baseSkuId;
        return baseSkuId + (uint256(foilVariant) * SKU_BLOCK);
    }

    function _skuIdFromBaseAndVariant(
        uint256 baseSkuId,
        uint8 foilVariant
    ) internal pure returns (uint256) {
        if (foilVariant > PRISMATIC_FOIL_VARIANT) revert InvalidSku();
        return _composeRevealSkuId(baseSkuId, foilVariant);
    }

    function _isPackSku(uint256 skuId) internal pure returns (bool) {
        return
            skuId == STANDARD_PACK_SKU_ID ||
            skuId == HOLO_PACK_SKU_ID ||
            skuId == PRISMATIC_PACK_SKU_ID;
    }

    function _metadataSkuIdForToken(
        uint256 tokenId
    ) internal view returns (uint256) {
        return _tokenSkuId[tokenId];
    }

    function _metadataBaseSkuId(
        uint256 skuId
    ) internal pure returns (uint256) {
        if (_isPackSku(skuId)) return STANDARD_PACK_SKU_ID;

        (uint256 baseSkuId, , bool valid) = _decodeSkuId(skuId);
        return valid ? baseSkuId : 0;
    }

    function _isValidMetadataSku(uint256 skuId) internal pure returns (bool) {
        if (_isPackSku(skuId)) return true;

        (, , bool valid) = _decodeSkuId(skuId);
        return valid;
    }

    function _decodeSkuId(
        uint256 skuId
    ) internal pure returns (uint256 baseSkuId, uint8 foilVariant, bool valid) {
        if (skuId < REVEALED_SKU_START_ID) return (0, 0, false);

        if (skuId >= REVEALED_SKU_START_ID + (SKU_BLOCK * 2)) {
            baseSkuId = skuId - (SKU_BLOCK * 2);
            foilVariant = PRISMATIC_FOIL_VARIANT;
        } else if (skuId >= REVEALED_SKU_START_ID + SKU_BLOCK) {
            baseSkuId = skuId - SKU_BLOCK;
            foilVariant = HOLO_FOIL_VARIANT;
        } else {
            baseSkuId = skuId;
            foilVariant = STANDARD_FOIL_VARIANT;
        }

        valid = _rarityByBaseSku(baseSkuId) != 0;
    }

    function _rarityByBaseSku(uint256 baseSkuId) internal pure returns (uint8) {
        return _fixedRarityByBaseSku(baseSkuId);
    }

    function _fixedRarityByBaseSku(
        uint256 baseSkuId
    ) internal pure returns (uint8) {
        if (baseSkuId < REVEALED_SKU_START_ID) return 0;

        uint256 index = baseSkuId - REVEALED_SKU_START_ID;
        if (index >= INITIAL_CARD_SKU_COUNT) return 0;

        uint256 packed = index < RARITY_MAP_CHUNK_SIZE
            ? RARITY_MAP_PACKED_0
            : RARITY_MAP_PACKED_1;
        uint256 packedIndex = index < RARITY_MAP_CHUNK_SIZE
            ? index
            : index - RARITY_MAP_CHUNK_SIZE;
        return
            uint8(
                (packed >> (packedIndex * RARITY_MAP_BITS)) &
                    uint256(0x7)
            );
    }

    function _fixedBaseSkuCountForRarity(
        uint8 rarity
    ) internal pure returns (uint256) {
        if (rarity == RARITY_COMMON) return INITIAL_COMMON_CARD_SKUS;
        if (rarity == RARITY_RARE) return INITIAL_RARE_CARD_SKUS;
        if (rarity == RARITY_EPIC) return INITIAL_EPIC_CARD_SKUS;
        if (rarity == RARITY_LEGENDARY) return INITIAL_LEGENDARY_CARD_SKUS;
        if (rarity == RARITY_MYTHIC) return INITIAL_MYTHIC_CARD_SKUS;
        return 0;
    }

    function _fixedBaseSkuIdByRarityIndex(
        uint8 rarity,
        uint256 index
    ) internal pure returns (uint256) {
        if (rarity == RARITY_COMMON) {
            if (index >= INITIAL_COMMON_CARD_SKUS) revert InvalidRarity();
            if (index < 32) {
                return
                    REVEALED_SKU_START_ID +
                    _packedSkuOffsetAt(COMMON_SKU_OFFSETS_0, index);
            }
            if (index < 64) {
                return
                    REVEALED_SKU_START_ID +
                    _packedSkuOffsetAt(COMMON_SKU_OFFSETS_1, index - 32);
            }
            return
                REVEALED_SKU_START_ID +
                _packedSkuOffsetAt(COMMON_SKU_OFFSETS_2, index - 64);
        }
        if (rarity == RARITY_RARE) {
            if (index >= INITIAL_RARE_CARD_SKUS) revert InvalidRarity();
            if (index < 32) {
                return
                    REVEALED_SKU_START_ID +
                    _packedSkuOffsetAt(RARE_SKU_OFFSETS_0, index);
            }
            return
                REVEALED_SKU_START_ID +
                _packedSkuOffsetAt(RARE_SKU_OFFSETS_1, index - 32);
        }
        if (rarity == RARITY_EPIC) {
            if (index >= INITIAL_EPIC_CARD_SKUS) revert InvalidRarity();
            if (index < 32) {
                return
                    REVEALED_SKU_START_ID +
                    _packedSkuOffsetAt(EPIC_SKU_OFFSETS_0, index);
            }
            return
                REVEALED_SKU_START_ID +
                _packedSkuOffsetAt(EPIC_SKU_OFFSETS_1, index - 32);
        }
        if (rarity == RARITY_LEGENDARY) {
            if (index >= INITIAL_LEGENDARY_CARD_SKUS) revert InvalidRarity();
            return
                REVEALED_SKU_START_ID +
                _packedSkuOffsetAt(LEGENDARY_SKU_OFFSETS_0, index);
        }
        if (rarity == RARITY_MYTHIC) {
            if (index >= INITIAL_MYTHIC_CARD_SKUS) revert InvalidRarity();
            return
                REVEALED_SKU_START_ID +
                _packedSkuOffsetAt(MYTHIC_SKU_OFFSETS_0, index);
        }
        revert InvalidRarity();
    }

    function _packedSkuOffsetAt(
        uint256 packed,
        uint256 index
    ) internal pure returns (uint256) {
        return (packed >> (index * SKU_OFFSET_BITS)) & uint256(0xff);
    }

    function _craftingActive() internal view returns (bool) {
        return MoggmonPackToken(payable(moggmonTokenAddress)).craftingActive();
    }

    function _publicMintEnabled() internal pure virtual returns (bool) {
        return true;
    }

    function _initialCraftingActive() internal pure virtual returns (bool) {
        return false;
    }

    function _allowAllowlistMintDuringCrafting() internal pure virtual returns (bool) {
        return false;
    }

    function _requiresFullAllowlistAllocation() internal pure virtual returns (bool) {
        return false;
    }

    function initialOwnerPackCount() public pure virtual returns (uint256) {
        return 0;
    }

    function _requireMetadataUpdateBatch(uint256 length) internal pure {
        if (length == 0) revert BatchEmpty();
        if (length > MAX_METADATA_UPDATE_BATCH_SIZE) revert BatchTooLarge();
    }

    function _emitAllTokenMetadataUpdateIfAny() internal {
        if (_tokenIdCounter != 0) {
            emit BatchMetadataUpdate(1, _tokenIdCounter);
        }
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address currentOwner = _ownerOf(tokenId);
        uint256 batchId = tokenToBatchId[tokenId];
        uint256 skuId = _tokenSkuId[tokenId];
        if (
            currentOwner != address(0) &&
            to != address(0) &&
            batchId != 0 &&
            _isPackSku(skuId) &&
            !_batchRandomnessFulfilled[batchId]
        ) {
            revert PackRevealPending();
        }

        address previousOwner = super._update(to, tokenId, auth);

        if (skuId != 0) {
            if (previousOwner != address(0)) {
                _ownerSkuBalance[previousOwner][skuId] -= 1;
            }
            if (to != address(0)) {
                _ownerSkuBalance[to][skuId] += 1;
            }
        }

        emit MoggmonAssetTransfer(
            previousOwner,
            to,
            tokenId,
            skuId,
            _totalSupplyBySku[skuId],
            totalSupply
        );

        return previousOwner;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    receive() external payable {}
}
