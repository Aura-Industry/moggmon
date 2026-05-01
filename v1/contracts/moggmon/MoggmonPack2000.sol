// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025 Beb, Inc.
pragma solidity ^0.8.24;

import {MoggmonPack} from "./MoggmonPack.sol";

/// @title MoggmonPack2000
/// @dev Legacy-named production implementation that graduates after the production mint cap.
contract MoggmonPack2000 is MoggmonPack {
    uint256 public constant PRODUCTION_PRIMARY_MINT_CAP = 1_250;

    function primaryMintCap() public pure override returns (uint256) {
        return PRODUCTION_PRIMARY_MINT_CAP;
    }
}
