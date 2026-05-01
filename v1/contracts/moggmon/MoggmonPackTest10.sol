// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {MoggmonPack} from "./MoggmonPack.sol";

/// @title MoggmonPackTest10
/// @dev Sepolia-only test implementation that graduates after 10 primary mints.
contract MoggmonPackTest10 is MoggmonPack {
    uint256 public constant TEST_PRIMARY_MINT_CAP = 10;

    function primaryMintCap() public pure override returns (uint256) {
        return TEST_PRIMARY_MINT_CAP;
    }
}
