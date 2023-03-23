//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { NFT } from "./NFT.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract NFTFactory is Ownable {}
