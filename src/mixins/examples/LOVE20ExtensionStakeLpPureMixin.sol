// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {ExtensionVerificationMixin} from "../ExtensionVerificationMixin.sol";
import {ExtensionScoreMixin} from "../ExtensionScoreMixin.sol";
import {ExtensionStakeMixin} from "../ExtensionStakeMixin.sol";
import {
    ILOVE20ExtensionCenter
} from "../../interface/ILOVE20ExtensionCenter.sol";
import {
    IUniswapV2Pair
} from "@core/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";

/// @title LOVE20ExtensionStakeLpPureMixin
/// @notice Pure Mixin版本的LP Staking Extension（不继承旧接口，演示Mixin架构）
/// @dev 这是一个使用纯 Mixin 架构重构的示例，展示了如何组合各个功能模块
///
/// **Mixin 组合说明:**
/// ```
/// CoreMixin        - 核心功能（工厂、初始化、协议接口）
///    +
/// AccountMixin     - 账户管理（追踪参与者）
///    +
/// RewardMixin      - 奖励分发（奖励计算和领取）
///    +
/// VerificationMixin - 验证信息管理
///    +
/// ScoreMixin       - 评分系统（基于评分的奖励分配）
///    +
/// StakeMixin       - 质押功能（stake/unstake/withdraw）
///    +
/// 自定义逻辑       - LP token 验证和评分计算
/// ```
///
/// **自定义功能:**
/// 1. LP Token 验证 - 必须是 Uniswap V2 Pair 且包含项目代币
/// 2. 双因素评分 - 基于 LP 质押量和治理投票数
/// 3. 治理比率乘数 - 平衡 LP 质押和治理参与的权重
/// 4. LP 转换功能 - 将 LP token 数量转换为底层代币数量
///
/// **核心优势:**
/// - ✅ 模块化 - 每个功能独立，易于测试
/// - ✅ 可复用 - Mixin 可以在其他扩展中重用
/// - ✅ 灵活 - 可以轻松添加或移除功能
/// - ✅ 清晰 - 单一职责，代码结构清晰
///
contract LOVE20ExtensionStakeLpPureMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionStakeMixin
{
    // ============================================
    // ERRORS
    // ============================================
    error InvalidStakeTokenAddress();

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Multiplier for governance votes in score calculation
    /// @dev Allows adjusting the weight of governance participation vs LP staking
    ///      Higher value = governance votes matter more
    ///      Example: govRatioMultiplier = 2 means governance votes count 2x
    uint256 public immutable govRatioMultiplier;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the LP staking extension
    /// @param factory_ The factory contract address
    /// @param stakeTokenAddress_ The LP token address (must be valid Uniswap V2 Pair)
    /// @param waitingPhases_ Number of phases to wait before withdrawal after unstaking
    /// @param govRatioMultiplier_ Multiplier for governance votes in score calculation
    /// @param minGovVotes_ Minimum governance votes required to stake
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 govRatioMultiplier_,
        uint256 minGovVotes_
    )
        ExtensionStakeMixin(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {
        govRatioMultiplier = govRatioMultiplier_;
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @notice Initialize the extension with token and action
    /// @dev Performs core initialization, validates LP token, and auto-joins the action
    /// @param tokenAddress_ The project token address
    /// @param actionId_ The action ID this extension is for
    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public override(ExtensionCoreMixin) onlyCenter {
        // 1. Initialize core (factory, token, action) and auto-join
        super.initialize(tokenAddress_, actionId_);

        // 2. Validate stake token is a valid LP pair
        _validateStakeToken();
    }

    /// @dev Validate that stake token is a valid Uniswap V2 Pair containing the project token
    ///      This ensures users can only stake relevant LP tokens
    function _validateStakeToken() internal view {
        address uniswapV2FactoryAddress = ILOVE20ExtensionCenter(center())
            .uniswapV2FactoryAddress();

        // Check 1: Verify it's a Uniswap V2 Pair from the correct factory
        try IUniswapV2Pair(stakeTokenAddress).factory() returns (
            address pairFactory
        ) {
            if (pairFactory != uniswapV2FactoryAddress) {
                revert InvalidStakeTokenAddress();
            }
        } catch {
            revert InvalidStakeTokenAddress();
        }
        // Check 2: Get the two tokens in the pair
        address pairToken0;
        address pairToken1;
        try IUniswapV2Pair(stakeTokenAddress).token0() returns (
            address token0
        ) {
            pairToken0 = token0;
        } catch {
            revert InvalidStakeTokenAddress();
        }
        try IUniswapV2Pair(stakeTokenAddress).token1() returns (
            address token1
        ) {
            pairToken1 = token1;
        } catch {
            revert InvalidStakeTokenAddress();
        }
        // Check 3: Verify one of the pair tokens is the project token
        if (pairToken0 != tokenAddress && pairToken1 != tokenAddress) {
            revert InvalidStakeTokenAddress();
        }
    }

    // ============================================
    // STAKE OPERATIONS - WITH VERIFICATION HOOKS
    // ============================================

    /// @notice Stake LP tokens to participate and earn rewards
    /// @dev Overrides parent to add verification result preparation before staking
    /// @param amount Amount of LP tokens to stake
    /// @param verificationInfos Array of verification information strings
    function stake(
        uint256 amount,
        string[] memory verificationInfos
    ) external override {
        // Prepare verification results BEFORE any state changes
        _prepareVerifyResultIfNeeded();

        // Execute stake logic from mixin
        _doStake(amount, verificationInfos);
    }

    /// @notice Request to unstake LP tokens
    /// @dev Overrides parent to add verification result preparation before unstaking
    function unstake() external override {
        // Prepare verification results BEFORE any state changes
        _prepareVerifyResultIfNeeded();

        // Execute unstake logic from mixin
        _doUnstake();
    }

    /// @notice Withdraw unstaked LP tokens after waiting period
    /// @dev Overrides parent to add verification result preparation before withdrawal
    function withdraw() external override {
        // Prepare verification results BEFORE any state changes
        _prepareVerifyResultIfNeeded();

        // Execute withdraw logic from mixin
        _doWithdraw();
    }

    // ============================================
    // OVERRIDE HOOK FUNCTIONS
    // ============================================

    /// @dev Override to resolve conflict between RewardMixin and ScoreMixin
    ///      ExtensionScoreMixin's implementation generates verification results for scoring
    function _prepareVerifyResultIfNeeded()
        internal
        virtual
        override(ExtensionRewardMixin, ExtensionScoreMixin)
    {
        ExtensionScoreMixin._prepareVerifyResultIfNeeded();
    }

    // ============================================
    // LP TOKEN UTILITY FUNCTIONS
    // ============================================

    /// @dev Convert LP token amount to underlying project token amount
    /// @param lpAmount The LP token amount
    /// @return The equivalent project token amount based on LP share of pool
    ///
    /// Formula: tokenAmount = (lpAmount * tokenReserve) / totalLpSupply
    ///
    /// Example:
    /// - Pool has 1000 project tokens and 10000 USDC
    /// - Total LP supply is 100
    /// - User has 10 LP tokens
    /// - tokenAmount = (10 * 1000) / 100 = 100 project tokens
    function _lpToTokenAmount(
        uint256 lpAmount
    ) internal view returns (uint256) {
        if (lpAmount == 0) {
            return 0;
        }

        IUniswapV2Pair pair = IUniswapV2Pair(stakeTokenAddress);

        // Get current reserves and total LP supply
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 totalLp = pair.totalSupply();

        if (totalLp == 0) {
            return 0;
        }

        // Determine which reserve is the project token
        address pairToken0 = pair.token0();
        uint256 tokenReserve = (pairToken0 == tokenAddress)
            ? uint256(reserve0)
            : uint256(reserve1);

        // Calculate proportional token amount
        return (lpAmount * tokenReserve) / totalLp;
    }

    /// @notice Check if joined value calculation is supported
    /// @return Always true for this extension
    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    /// @notice Get total value of all staked LP in terms of project tokens
    /// @return Total project token value across all staked LP
    function joinedValue() external view returns (uint256) {
        return _lpToTokenAmount(totalStakedAmount);
    }

    /// @notice Get value of an account's staked LP in terms of project tokens
    /// @param account The account address
    /// @return Project token value of the account's staked LP
    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        return _lpToTokenAmount(_stakeInfo[account].amount);
    }

    // ============================================
    // SCORE CALCULATION - DUAL FACTOR ALGORITHM
    // ============================================

    /// @notice Calculate scores for all stakers using dual-factor algorithm
    /// @dev Score calculation logic:
    ///
    /// **Dual-Factor Score Model:**
    /// 1. **LP Token Ratio** = (user's staked LP / total LP supply) * 1000000
    ///    - Measures user's LP staking participation
    ///
    /// 2. **Governance Ratio** = (user's votes / total votes) * govRatioMultiplier * 1000000
    ///    - Measures user's governance participation
    ///    - Multiplier adjusts governance weight
    ///
    /// 3. **Final Score** = min(LP Ratio, Governance Ratio)
    ///    - Takes the MINIMUM of the two ratios
    ///    - This ensures BOTH are required for maximum rewards
    ///
    /// **Why Minimum?**
    /// - Prevents users from getting full rewards with only LP staking
    /// - Prevents users from getting full rewards with only governance votes
    /// - Encourages balanced participation in both aspects
    ///
    /// **Example:**
    /// - User stakes 10% of LP (lpRatio = 100000)
    /// - User has 5% of votes with 2x multiplier (govRatio = 100000)
    /// - Score = min(100000, 100000) = 100000
    ///
    /// But if user only stakes LP without governance:
    /// - lpRatio = 100000, govRatio = 0
    /// - Score = 0 (gets no rewards!)
    ///
    /// @return totalCalculated Sum of all scores
    /// @return scoresCalculated Array of individual scores (aligned with _accounts)
    function calculateScores()
        public
        view
        override(ExtensionScoreMixin)
        returns (uint256 totalCalculated, uint256[] memory scoresCalculated)
    {
        uint256 totalTokenSupply = _stakeToken.totalSupply();
        uint256 totalGovVotes = _stake.govVotesNum(tokenAddress);

        // Edge case: Return empty if no LP supply or no governance votes
        if (totalTokenSupply == 0 || totalGovVotes == 0) {
            return (0, new uint256[](0));
        }

        scoresCalculated = new uint256[](_accounts.length);

        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];

            // Get user's staked amount and governance votes
            uint256 stakedAmount = _stakeInfo[account].amount;
            uint256 govVotes = _stake.validGovVotes(tokenAddress, account);

            // Factor 1: LP token ratio (scaled by 1000000 for precision)
            uint256 tokenRatio = (stakedAmount * 1000000) / totalTokenSupply;

            // Factor 2: Governance votes ratio (with multiplier)
            uint256 govVotesRatio = (govVotes * 1000000 * govRatioMultiplier) /
                totalGovVotes;

            // Final score is the MINIMUM of the two factors
            // This is the key mechanism that enforces balanced participation
            uint256 score = tokenRatio > govVotesRatio
                ? govVotesRatio // Governance is limiting factor
                : tokenRatio; // LP staking is limiting factor

            scoresCalculated[i] = score;
            totalCalculated += score;
        }

        return (totalCalculated, scoresCalculated);
    }

    /// @notice Calculate score for a specific account
    /// @dev Calculates all scores then filters for the target account
    /// @param account The account address to calculate score for
    /// @return total Total score across all stakers
    /// @return score The score for the specified account
    function calculateScore(
        address account
    )
        public
        view
        override(ExtensionScoreMixin)
        returns (uint256 total, uint256 score)
    {
        // Calculate all scores
        uint256[] memory scoresCalculated;
        (total, scoresCalculated) = calculateScores();

        // Find the specific account's score
        score = 0;
        for (uint256 i = 0; i < scoresCalculated.length; i++) {
            if (_accounts[i] == account) {
                score = scoresCalculated[i];
                break;
            }
        }

        return (total, score);
    }
}
