// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./Zap.sol";
import "./extensions/ZapLPMigrator.sol";

contract ZapFullV0 is Zap, ZapLPMigrator  {
  constructor(address _router) Zap(_router) {}
}