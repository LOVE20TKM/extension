// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";

/// @title PoolDistrustVotingMixin
/// @notice Mixin for pool governance distrust voting mechanism
/// @dev Allows governance token holders to vote against pools
///
/// **Voting Rules:**
/// - Only governance token holders who completed non-abstain verification
/// - Can vote against any pool in verify phase
/// - Vote amount cannot exceed voter's verification votes
/// - Reduces pool rewards based on distrust ratio
///
abstract contract PoolDistrustVotingMixin is ExtensionCoreMixin {
    // ============================================
    // ERRORS
    // ============================================
    error NotInVerifyPhase();
    error NotGovernor();
    error InsufficientVotingPower();
    error VoteAmountExceedsLimit();
    error AlreadyVotedMaximum();
    error InvalidVoteAmount();

    // ============================================
    // EVENTS
    // ============================================
    event DistrustVoted(
        uint256 indexed poolId,
        uint256 indexed round,
        address indexed voter,
        uint256 voteAmount,
        uint256 totalDistrustVotes
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Distrust vote data for a pool in a round
    struct DistrustVoteData {
        uint256 totalVotes; // Total distrust votes received
        mapping(address => uint256) voterVotes; // Voter => their vote amount
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Mapping: poolId => round => distrust vote data
    mapping(uint256 => mapping(uint256 => DistrustVoteData))
        internal _distrustVotes;

    // ============================================
    // DISTRUST VOTING
    // ============================================

    /// @notice Vote distrust against a pool
    /// @param poolId Pool ID to vote against
    /// @param voteAmount Amount of votes to cast
    /// @dev Voter must have sufficient verification votes
    function voteDistrust(uint256 poolId, uint256 voteAmount) public virtual {
        if (voteAmount == 0) {
            revert InvalidVoteAmount();
        }

        // Check if caller is a governor
        if (!canVoteDistrust(msg.sender)) {
            revert NotGovernor();
        }

        uint256 currentRound = _verify.currentRound();

        // Get voter's available votes
        uint256 availableVotes = getAvailableVotes(msg.sender, currentRound);
        if (availableVotes == 0) {
            revert InsufficientVotingPower();
        }

        // Get current votes from this voter
        uint256 currentVotes = _distrustVotes[poolId][currentRound].voterVotes[
            msg.sender
        ];
        uint256 totalNeeded = currentVotes + voteAmount;

        if (totalNeeded > availableVotes) {
            revert VoteAmountExceedsLimit();
        }

        // Update votes
        _distrustVotes[poolId][currentRound].voterVotes[
            msg.sender
        ] = totalNeeded;
        _distrustVotes[poolId][currentRound].totalVotes += voteAmount;

        emit DistrustVoted(
            poolId,
            currentRound,
            msg.sender,
            voteAmount,
            _distrustVotes[poolId][currentRound].totalVotes
        );
    }

    // ============================================
    // PENALTY CALCULATION
    // ============================================

    /// @notice Calculate penalty ratio for a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return penaltyRatio Penalty ratio in basis points (10000 = 100%)
    /// @dev Formula: penaltyRatio = (distrustVotes / totalVerifyVotes) * 10000
    function calculatePenaltyRatio(
        uint256 poolId,
        uint256 round
    ) public view returns (uint256 penaltyRatio) {
        uint256 distrustVotes = _distrustVotes[poolId][round].totalVotes;

        if (distrustVotes == 0) {
            return 0;
        }

        // Get total non-abstain verification votes for this action
        uint256 totalVerifyVotes = getTotalVerifyVotes(round);

        if (totalVerifyVotes == 0) {
            return 0;
        }

        // penaltyRatio = (distrustVotes / totalVerifyVotes) * 10000
        // Max penalty is 100% (10000)
        penaltyRatio = (distrustVotes * 10000) / totalVerifyVotes;

        if (penaltyRatio > 10000) {
            penaltyRatio = 10000; // Cap at 100%
        }

        return penaltyRatio;
    }

    /// @notice Get total verify votes for the action in a round
    /// @param round Round number
    /// @return Total non-abstain verification votes
    function getTotalVerifyVotes(uint256 round) public view returns (uint256) {
        // Get all accounts that verified this action
        // This should be implemented by the concrete contract based on verify mechanism
        return _getTotalVerifyVotesImpl(round);
    }

    // ============================================
    // VOTING POWER CALCULATION
    // ============================================

    /// @notice Check if address can vote distrust
    /// @param voter Address to check
    /// @return True if voter completed non-abstain verification
    function canVoteDistrust(address voter) public view returns (bool) {
        uint256 currentRound = _verify.currentRound();

        // Only need to check if voter completed verification
        // (Having verification votes already implies having governance votes)
        return _hasCompletedVerification(voter, currentRound);
    }

    /// @notice Get voter's available distrust votes
    /// @param voter Voter address
    /// @param round Round number
    /// @return Available votes (equal to verification votes)
    function getAvailableVotes(
        address voter,
        uint256 round
    ) public view returns (uint256) {
        // Voter can cast votes up to their verification vote amount
        return _getVoterVerificationVotes(voter, round);
    }

    /// @notice Get voter's remaining votes for a specific pool
    /// @param voter Voter address
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Remaining votes available
    function getRemainingVotes(
        address voter,
        uint256 poolId,
        uint256 round
    ) public view returns (uint256) {
        uint256 available = getAvailableVotes(voter, round);
        uint256 used = _distrustVotes[poolId][round].voterVotes[voter];
        return available > used ? available - used : 0;
    }

    // ============================================
    // VIEW FUNCTIONS - DISTRUST DATA
    // ============================================

    /// @notice Get total distrust votes for a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Total distrust votes
    function getDistrustVotes(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _distrustVotes[poolId][round].totalVotes;
    }

    /// @notice Get voter's votes against a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param voter Voter address
    /// @return Vote amount
    function getVoterDistrustVotes(
        uint256 poolId,
        uint256 round,
        address voter
    ) external view returns (uint256) {
        return _distrustVotes[poolId][round].voterVotes[voter];
    }

    /// @notice Check if voter has voted against a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param voter Voter address
    /// @return True if voter cast any votes
    function hasVotedDistrust(
        uint256 poolId,
        uint256 round,
        address voter
    ) external view returns (bool) {
        return _distrustVotes[poolId][round].voterVotes[voter] > 0;
    }

    /// @notice Get distrust voting info for a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return totalVotes Total distrust votes
    /// @return penaltyRatio Penalty ratio in basis points
    /// @return totalVerifyVotes Total verification votes
    function getDistrustInfo(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            uint256 totalVotes,
            uint256 penaltyRatio,
            uint256 totalVerifyVotes
        )
    {
        totalVotes = _distrustVotes[poolId][round].totalVotes;
        penaltyRatio = calculatePenaltyRatio(poolId, round);
        totalVerifyVotes = getTotalVerifyVotes(round);
        return (totalVotes, penaltyRatio, totalVerifyVotes);
    }

    /// @notice Get voter's distrust voting info
    /// @param voter Voter address
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return available Available votes
    /// @return used Votes already cast
    /// @return remaining Votes remaining
    function getVoterDistrustInfo(
        address voter,
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (uint256 available, uint256 used, uint256 remaining)
    {
        available = getAvailableVotes(voter, round);
        used = _distrustVotes[poolId][round].voterVotes[voter];
        remaining = available > used ? available - used : 0;
        return (available, used, remaining);
    }

    // ============================================
    // VALIDATION FUNCTIONS
    // ============================================

    /// @notice Check if voter can vote against a pool
    /// @param voter Voter address
    /// @param poolId Pool ID
    /// @param voteAmount Amount to vote
    /// @return allowed True if can vote
    /// @return reason Reason if cannot (empty if can)
    function canVote(
        address voter,
        uint256 poolId,
        uint256 voteAmount
    ) external view returns (bool allowed, string memory reason) {
        if (voteAmount == 0) {
            return (false, "Invalid vote amount");
        }

        if (!canVoteDistrust(voter)) {
            return (false, "Not a governor or not verified");
        }

        uint256 currentRound = _verify.currentRound();
        uint256 available = getAvailableVotes(voter, currentRound);

        if (available == 0) {
            return (false, "No voting power");
        }

        uint256 currentVotes = _distrustVotes[poolId][currentRound].voterVotes[
            voter
        ];

        if (currentVotes + voteAmount > available) {
            return (false, "Vote amount exceeds limit");
        }

        return (true, "");
    }

    // ============================================
    // INTERNAL HOOKS (to be implemented by concrete contract)
    // ============================================

    /// @dev Get total verification votes for the action
    /// @param round Round number
    /// @return Total verify votes
    function _getTotalVerifyVotesImpl(
        uint256 round
    ) internal view virtual returns (uint256);

    /// @dev Check if voter completed verification
    /// @param voter Voter address
    /// @param round Round number
    /// @return True if completed
    function _hasCompletedVerification(
        address voter,
        uint256 round
    ) internal view virtual returns (bool);

    /// @dev Get voter's verification votes
    /// @param voter Voter address
    /// @param round Round number
    /// @return Verification votes
    function _getVoterVerificationVotes(
        address voter,
        uint256 round
    ) internal view virtual returns (uint256);
}

