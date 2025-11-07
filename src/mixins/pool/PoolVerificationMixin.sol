// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolSnapshotMixin} from "./PoolSnapshotMixin.sol";

/// @title PoolVerificationMixin
/// @notice Mixin for pool verification mechanism
/// @dev Handles verification submission and validation
///
/// **Verification Rules:**
/// - Pool owner or designated verifier can submit
/// - Based on snapshot data
/// - Total scores cannot exceed pool participation amount
/// - Triggers snapshot when submitting
///
abstract contract PoolVerificationMixin is PoolSnapshotMixin {
    // ============================================
    // ERRORS
    // ============================================
    error VerificationAlreadySubmitted();
    error InvalidVerificationData();
    error ScoresExceedCapacity();
    error MinerNotInSnapshot();
    error SnapshotNotGenerated();
    error EmptyVerification();
    error MinerCountMismatch();

    // ============================================
    // EVENTS
    // ============================================
    event VerificationSubmitted(
        uint256 indexed poolId,
        uint256 indexed round,
        address indexed submitter,
        uint256 minerCount,
        uint256 totalScores,
        uint256 timestamp
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Verification result structure (optimized with mapping)
    /// @dev Miners list is not stored here, use snapshot.miners instead
    struct VerificationResult {
        address submitter; // Who submitted (owner or verifier)
        mapping(address => uint256) minerScores; // Miner => verification score (O(1) lookup)
        uint256 minerCount; // Number of miners verified (must equal snapshot.miners.length)
        uint256 totalScores; // Total verification scores
        uint256 timestamp; // Submission timestamp
        bool submitted; // Whether verification was submitted
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Mapping: poolId => round => verification result
    mapping(uint256 => mapping(uint256 => VerificationResult))
        internal _verifications;

    // ============================================
    // VERIFICATION SUBMISSION
    // ============================================

    /// @notice Submit verification result for a pool
    /// @param poolId Pool ID
    /// @param miners Array of miner addresses to verify (must match snapshot exactly)
    /// @param scores Array of scores (verification votes) for each miner
    /// @dev Can only be called by pool owner or designated verifier
    /// @dev Must verify ALL miners in snapshot (no partial verification allowed)
    function submitVerification(
        uint256 poolId,
        address[] memory miners,
        uint256[] memory scores
    ) public virtual poolExists(poolId) onlyPoolOwnerOrVerifier(poolId) {
        uint256 currentRound = _join.currentRound();

        // Cannot verify in round 0
        if (currentRound == 0) {
            revert InvalidVerificationData();
        }

        // Check if already submitted
        if (_verifications[poolId][currentRound].submitted) {
            revert VerificationAlreadySubmitted();
        }

        // Validate input lengths match
        if (miners.length != scores.length) {
            revert InvalidVerificationData();
        }

        if (miners.length == 0) {
            revert EmptyVerification();
        }

        // Trigger snapshot BEFORE validation
        _triggerSnapshotIfNeeded(poolId);

        // Get snapshot for validation
        PoolSnapshot storage snapshot = _snapshots[poolId][currentRound];
        if (!snapshot.generated) {
            revert SnapshotNotGenerated();
        }

        // Require verification count to match snapshot count (must verify ALL miners)
        if (miners.length != snapshot.miners.length) {
            revert MinerCountMismatch();
        }

        // Store verification result and validate
        VerificationResult storage result = _verifications[poolId][
            currentRound
        ];
        uint256 totalScores = 0;

        for (uint256 i = 0; i < miners.length; i++) {
            address miner = miners[i];

            // Check miner exists in snapshot
            bool found = false;
            for (uint256 j = 0; j < snapshot.miners.length; j++) {
                if (snapshot.miners[j] == miner) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert MinerNotInSnapshot();
            }

            // Store score in mapping
            result.minerScores[miner] = scores[i];
            totalScores += scores[i];
        }

        // Verify total scores do not exceed pool participation amount
        if (totalScores > snapshot.totalAmount) {
            revert ScoresExceedCapacity();
        }

        // Update result metadata
        result.submitter = msg.sender;
        result.minerCount = miners.length;
        result.totalScores = totalScores;
        result.timestamp = block.timestamp;
        result.submitted = true;

        emit VerificationSubmitted(
            poolId,
            currentRound,
            msg.sender,
            miners.length,
            totalScores,
            block.timestamp
        );
    }

    // ============================================
    // VIEW FUNCTIONS - VERIFICATION DATA
    // ============================================

    /// @notice Get verification result summary (cannot return mapping directly)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return submitted Whether verification was submitted
    /// @return submitter Who submitted
    /// @return minerCount Number of miners verified
    /// @return totalScores Total scores
    /// @return timestamp When submitted
    /// @dev Use getVerificationMinersAndScores() to get full miner list with scores
    function getVerification(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            bool submitted,
            address submitter,
            uint256 minerCount,
            uint256 totalScores,
            uint256 timestamp
        )
    {
        VerificationResult storage result = _verifications[poolId][round];
        return (
            result.submitted,
            result.submitter,
            result.minerCount,
            result.totalScores,
            result.timestamp
        );
    }

    /// @notice Check if verification was submitted
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return True if verification was submitted
    function isVerificationSubmitted(
        uint256 poolId,
        uint256 round
    ) external view returns (bool) {
        return _verifications[poolId][round].submitted;
    }

    /// @notice Get miner's score in verification
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return Score (0 if not found or not verified)
    function getVerificationMinerScore(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (uint256) {
        VerificationResult storage result = _verifications[poolId][round];

        if (!result.submitted) {
            return 0;
        }

        // Direct O(1) lookup from mapping
        return result.minerScores[miner];
    }

    /// @notice Get verification total scores
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Total scores
    function getVerificationTotalScores(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _verifications[poolId][round].totalScores;
    }

    /// @notice Get verification miner count
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Number of miners verified
    function getVerificationMinerCount(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _verifications[poolId][round].minerCount;
    }

    /// @notice Get verification miners and scores (fetches from snapshot)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return miners Array of verified miner addresses (from snapshot)
    /// @return scores Array of scores corresponding to miners
    /// @dev This function reads miners from snapshot and scores from verification mapping
    function getVerificationMinersAndScores(
        uint256 poolId,
        uint256 round
    ) external view returns (address[] memory miners, uint256[] memory scores) {
        VerificationResult storage result = _verifications[poolId][round];

        if (!result.submitted) {
            return (new address[](0), new uint256[](0));
        }

        // Get miners from snapshot
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        miners = snapshot.miners;

        // Get scores from verification mapping
        scores = new uint256[](miners.length);
        for (uint256 i = 0; i < miners.length; i++) {
            scores[i] = result.minerScores[miners[i]];
        }

        return (miners, scores);
    }

    /// @notice Get verification miners array (from snapshot)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Array of verified miner addresses
    /// @dev Returns snapshot.miners since all miners are verified
    function getVerificationMiners(
        uint256 poolId,
        uint256 round
    ) external view returns (address[] memory) {
        if (!_verifications[poolId][round].submitted) {
            return new address[](0);
        }
        return _snapshots[poolId][round].miners;
    }

    /// @notice Get verification scores array (ordered by snapshot.miners)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Array of scores
    function getVerificationScores(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256[] memory) {
        VerificationResult storage result = _verifications[poolId][round];

        if (!result.submitted) {
            return new uint256[](0);
        }

        // Get miners from snapshot and lookup scores
        address[] memory miners = _snapshots[poolId][round].miners;
        uint256[] memory scores = new uint256[](miners.length);

        for (uint256 i = 0; i < miners.length; i++) {
            scores[i] = result.minerScores[miners[i]];
        }

        return scores;
    }

    // ============================================
    // VIEW FUNCTIONS - VERIFICATION QUERIES
    // ============================================

    /// @notice Get verification info summary
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return submitted Whether verification was submitted
    /// @return submitter Who submitted
    /// @return minerCount Number of miners verified
    /// @return totalScores Total verification scores
    /// @return timestamp When submitted
    function getVerificationInfo(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            bool submitted,
            address submitter,
            uint256 minerCount,
            uint256 totalScores,
            uint256 timestamp
        )
    {
        VerificationResult storage result = _verifications[poolId][round];
        return (
            result.submitted,
            result.submitter,
            result.minerCount,
            result.totalScores,
            result.timestamp
        );
    }

    /// @notice Check if miner was verified
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return True if miner was verified (has non-zero score)
    function wasMinerVerified(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (bool) {
        VerificationResult storage result = _verifications[poolId][round];

        if (!result.submitted) {
            return false;
        }

        // O(1) lookup and check if score > 0
        return result.minerScores[miner] > 0;
    }

    /// @notice Get verification effectiveness
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return effectiveness Percentage of capacity utilized (basis points, 10000 = 100%)
    function getVerificationEffectiveness(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256 effectiveness) {
        VerificationResult storage result = _verifications[poolId][round];

        if (!result.submitted) {
            return 0;
        }

        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        if (snapshot.totalAmount == 0) {
            return 0;
        }

        // effectiveness = (totalScores / totalAmount) * 10000
        return (result.totalScores * 10000) / snapshot.totalAmount;
    }

    /// @notice Check if verification is valid for a pool
    /// @param poolId Pool ID
    /// @param miners Array of miners
    /// @param scores Array of scores
    /// @return isValid True if verification would be valid
    /// @return reason Reason if invalid (empty if valid)
    function canSubmitVerification(
        uint256 poolId,
        address[] memory miners,
        uint256[] memory scores
    ) external view returns (bool isValid, string memory reason) {
        // Check if pool exists
        if (_pools[poolId].owner == address(0)) {
            return (false, "Pool does not exist");
        }

        // Check if caller can verify
        if (!canVerify(msg.sender, poolId)) {
            return (false, "Not authorized to verify");
        }

        uint256 currentRound = _join.currentRound();

        // Check if already submitted
        if (_verifications[poolId][currentRound].submitted) {
            return (false, "Verification already submitted");
        }

        // Check input lengths match
        if (miners.length != scores.length) {
            return (false, "Miners and scores length mismatch");
        }

        if (miners.length == 0) {
            return (false, "Empty verification");
        }

        // Check if snapshot exists
        if (!_snapshots[poolId][currentRound].generated) {
            return (false, "Snapshot not generated yet");
        }

        PoolSnapshot storage snapshot = _snapshots[poolId][currentRound];

        // Check if verification count matches snapshot count (must verify ALL miners)
        if (miners.length != snapshot.miners.length) {
            return (false, "Must verify all miners in snapshot");
        }

        // Validate miners and calculate total
        uint256 totalScores = 0;
        for (uint256 i = 0; i < miners.length; i++) {
            // Check if miner in snapshot
            bool found = false;
            for (uint256 j = 0; j < snapshot.miners.length; j++) {
                if (snapshot.miners[j] == miners[i]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return (false, "Miner not in snapshot");
            }

            totalScores += scores[i];
        }

        // Check total scores
        if (totalScores > snapshot.totalAmount) {
            return (false, "Scores exceed capacity");
        }

        return (true, "");
    }
}
