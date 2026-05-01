// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {MoggmonPackToken} from "./MoggmonPackToken.sol";
import {MoggmonPack} from "./MoggmonPack.sol";

/// @title MoggmonPackFactory
/// @dev Factory for deploying flat-price Moggmon pack token and NFT clones.
contract MoggmonPackFactory is Ownable {
    string internal constant DEFAULT_BASE_URI =
        "https://api.auramaxx.gg/metadata/moggmon/";

    event MoggmonDropCreated(
        address indexed creator,
        address indexed tokenContract,
        address indexed dropContract,
        string tokenName,
        string tokenSymbol,
        string nftName,
        string nftSymbol
    );

    address public tokenImplementation;
    address public dropImplementation;
    address public defaultMetadataFallbackContract;
    string public defaultBaseURI;

    error AddressZero();
    error InsufficientETHSent();
    error InvalidConfiguration();
    error TransferFailed();

    constructor(
        address tokenImplementation_,
        address dropImplementation_
    ) Ownable(msg.sender) {
        _setFactoryState(
            tokenImplementation_,
            dropImplementation_
        );
    }

    function createDrop(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata nftName,
        string calldata nftSymbol
    ) external payable returns (address tokenContract, address dropContract) {
        return
            createDropWithSettings(
                tokenName,
                tokenSymbol,
                nftName,
                nftSymbol,
                msg.sender,
                0,
                defaultBaseURI,
                bytes32(0),
                0,
                0,
                false
            );
    }

    function createDropWithSettings(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata nftName,
        string calldata nftSymbol,
        address owner_,
        uint256 amount,
        string memory baseURI_,
        bytes32 merkleRoot_,
        uint256 wlPacks_,
        uint256 wlPacksPerAddress_,
        bool allowlistNoTimeLimit_
    ) public payable returns (address tokenContract, address dropContract) {
        if (bytes(tokenName).length == 0) revert InvalidConfiguration();
        if (bytes(tokenSymbol).length == 0) revert InvalidConfiguration();
        if (bytes(nftName).length == 0) revert InvalidConfiguration();
        if (bytes(nftSymbol).length == 0) revert InvalidConfiguration();
        if (bytes(baseURI_).length == 0) revert InvalidConfiguration();
        if (owner_ == address(0)) revert AddressZero();

        tokenContract = Clones.clone(tokenImplementation);
        dropContract = Clones.clone(dropImplementation);

        MoggmonPack.InitializeParams memory dropParams = MoggmonPack
            .InitializeParams({
                owner: owner_,
                nftName: nftName,
                nftSymbol: nftSymbol,
                tokenAddress: tokenContract,
                factory: address(this),
                baseURI: baseURI_,
                metadataFallbackContract: defaultMetadataFallbackContract,
                merkleRoot: merkleRoot_,
                wlPacks: wlPacks_,
                wlPacksPerAddress: wlPacksPerAddress_,
                allowlistNoTimeLimit: allowlistNoTimeLimit_
            });
        MoggmonPack(payable(dropContract)).initialize(dropParams);
        MoggmonPackToken(payable(tokenContract)).initialize(
            owner_,
            tokenName,
            tokenSymbol,
            dropContract,
            address(this),
            MoggmonPack(payable(dropContract)).primaryMintCap(),
            MoggmonPack(payable(dropContract)).tokensPerMint()
        );
        MoggmonPack(payable(dropContract)).activateInitialCrafting();

        if (amount > 0) {
            uint256 mintPrice = MoggmonPack(payable(dropContract)).getMintPrice(
                amount
            );
            if (msg.value < mintPrice) revert InsufficientETHSent();

            MoggmonPack(payable(dropContract)).mint{value: mintPrice}(
                amount,
                msg.sender,
                address(0),
                address(0)
            );
            _refundExcess(msg.value - mintPrice);
        } else {
            _refundExcess(msg.value);
        }

        emit MoggmonDropCreated(
            owner_,
            tokenContract,
            dropContract,
            tokenName,
            tokenSymbol,
            nftName,
            nftSymbol
        );

        return (tokenContract, dropContract);
    }

    function updateDefaultPackSettings(string calldata newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) revert InvalidConfiguration();
        defaultBaseURI = newBaseURI;
    }

    function updateDefaultMetadataFallbackContract(
        address newMetadataFallbackContract
    ) external onlyOwner {
        if (
            newMetadataFallbackContract != address(0) &&
            newMetadataFallbackContract.code.length == 0
        ) {
            revert InvalidConfiguration();
        }
        defaultMetadataFallbackContract = newMetadataFallbackContract;
    }

    function updateTokenImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert AddressZero();
        tokenImplementation = newImplementation;
    }

    function updateDropImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert AddressZero();
        dropImplementation = newImplementation;
    }

    function _setFactoryState(
        address tokenImplementation_,
        address dropImplementation_
    ) internal {
        if (tokenImplementation_ == address(0)) revert AddressZero();
        if (dropImplementation_ == address(0)) revert AddressZero();

        tokenImplementation = tokenImplementation_;
        dropImplementation = dropImplementation_;
        defaultBaseURI = DEFAULT_BASE_URI;
    }

    function _refundExcess(uint256 amount) internal {
        if (amount == 0) return;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
