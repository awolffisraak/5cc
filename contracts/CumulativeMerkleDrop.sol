// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/ICumulativeMerkleDrop.sol";


contract CumulativeMerkleDrop is Ownable, ICumulativeMerkleDrop {
    using SafeERC20 for IERC20;

    address public immutable override token;

    bytes32 public override merkleRoot;
    mapping(address => uint256) public cumulativeClaimed;

    constructor(address token_) {
        token = token_;
    }

    function setMerkleRoot(bytes32 merkleRoot_) external override onlyOwner {
        emit MerkelRootUpdated(merkleRoot, merkleRoot_);
        merkleRoot = merkleRoot_;
    }

    function claim(
        uint256 index,
        address account,
        uint256 amountToClaim,
        uint256 cumulativeAmount,
        bytes32 targetMerkleRoot,
        bytes32[] calldata merkleProof
    ) external override {
        require(merkleRoot == targetMerkleRoot, "CMD: Merkle root was updated");

        // Verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(account, cumulativeAmount));
        require(targetMerkleRoot == applyProof(index, node, merkleProof), "CMD: Invalid proof");

        // Mark it claimed
        uint256 claimed = cumulativeClaimed[account] + amountToClaim;
        cumulativeClaimed[account] = claimed;
        if (claimed - amountToClaim == cumulativeAmount) {
            revert("CMD: Drop already claimed");
        }
        else if (claimed > cumulativeAmount) {
            revert("CMD: Claiming amount is too high");
        }

        // Send the token
        IERC20(token).safeTransfer(account, amountToClaim);
        emit Claimed(index, account, amountToClaim);
    }

    function applyProof(
        uint256 index,
        bytes32 leaf,
        bytes32[] calldata proof
    ) public pure returns (bytes32 computedHash) {
        computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            if ((index >> i) & 1 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, proof[i]));
            } else {
                computedHash = keccak256(abi.encodePacked(proof[i], computedHash));
            }
        }
    }
}