// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {MoggmonPack} from "./MoggmonPack.sol";

/// @title MoggmonPackV2Claim2988
/// @dev V2 claim implementation capped to the final revised primary-minter allocation.
contract MoggmonPackV2Claim2988 is MoggmonPack {
    uint256 public constant V2_CLAIM_PRIMARY_MINT_CAP = 2_988;
    uint256 public constant V2_TOTAL_PACK_SUPPLY = 3_000;
    uint256 public constant TEST_PACK_COUNT =
        V2_TOTAL_PACK_SUPPLY - V2_CLAIM_PRIMARY_MINT_CAP;

    function primaryMintCap() public pure override returns (uint256) {
        return V2_CLAIM_PRIMARY_MINT_CAP;
    }

    function initialOwnerPackCount() public pure override returns (uint256) {
        return TEST_PACK_COUNT;
    }

    function _publicMintEnabled() internal pure override returns (bool) {
        return false;
    }

    function _initialCraftingActive() internal pure override returns (bool) {
        return true;
    }

    function _allowAllowlistMintDuringCrafting() internal pure override returns (bool) {
        return true;
    }

    function _requiresFullAllowlistAllocation() internal pure override returns (bool) {
        return true;
    }
}
