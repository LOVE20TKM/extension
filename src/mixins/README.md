# LOVE20 Extension Mixin Architecture

## 📖 Overview

This directory contains a mixin-based architecture for building LOVE20 extensions. The mixin pattern allows you to compose functionality by combining independent, reusable modules instead of using deep inheritance chains.

## 🏗️ Architecture Benefits

### Before (Deep Inheritance)
```
Base → AutoScore → Join/Stake
```
- Tight coupling
- Hard to customize
- Inflexible composition

### After (Mixin Composition)
```
Core + Account + Reward + Verification + Score + Join/Stake
```
- Loose coupling
- Easy to customize
- Flexible composition
- Single Responsibility Principle

## 🧩 Available Mixins

### 1. **ExtensionCoreMixin**
Core functionality for all extensions.

**Provides:**
- Factory and center contract references
- Protocol contract interfaces (Launch, Stake, Submit, Vote, Join, Verify, Mint, Random)
- Basic initialization
- Access control (onlyCenter modifier)

**Use when:** Always - this is the foundation for all extensions

```solidity
contract MyExtension is ExtensionCoreMixin {
    constructor(address factory_) ExtensionCoreMixin(factory_) {}
}
```

---

### 2. **ExtensionAccountMixin**
Account management functionality.

**Provides:**
- Account list storage and management
- Add/remove accounts
- Query functions (accounts, accountsCount, accountAtIndex)

**Use when:** Your extension needs to track participants

```solidity
contract MyExtension is 
    ExtensionCoreMixin,
    ExtensionAccountMixin 
{
    function someFunction() {
        _addAccount(msg.sender);  // Use internal helper
    }
}
```

---

### 3. **ExtensionRewardMixin**
Reward distribution system.

**Provides:**
- Reward storage per round
- Reward claiming functionality
- Abstract reward calculation hook

**Use when:** Your extension distributes rewards

**Must implement:**
```solidity
function rewardByAccount(uint256 round, address account) 
    public view virtual returns (uint256 reward, bool isMinted);
```

---

### 4. **ExtensionVerificationMixin**
Verification information management.

**Provides:**
- Verification info storage by round
- Update and query functions
- Historical verification data tracking

**Use when:** Your extension needs verification info from users

```solidity
contract MyExtension is 
    ExtensionCoreMixin,
    ExtensionVerificationMixin 
{
    function myFunction(string[] memory infos) {
        updateVerificationInfo(infos);
    }
}
```

---

### 5. **ExtensionScoreMixin**
Score-based reward calculation.

**Provides:**
- Score storage and management
- Score-based reward distribution
- Automatic verification result generation

**Requires:**
- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionRewardMixin

**Must implement:**
```solidity
function calculateScores() 
    public view virtual 
    returns (uint256 total, uint256[] memory scores);

function calculateScore(address account) 
    public view virtual 
    returns (uint256 total, uint256 score);
```

**Use when:** Your extension uses scoring logic for rewards

---

### 6. **ExtensionJoinMixin**
Join/withdraw functionality with block-based waiting period.

**Provides:**
- Join with token amount
- Withdraw after waiting blocks
- Minimum governance votes check
- Join info tracking

**Requires:**
- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionVerificationMixin

**Parameters:**
- `joinTokenAddress`: Token to join with
- `waitingBlocks`: Blocks to wait before withdrawal
- `minGovVotes`: Minimum governance votes required

**Use when:** Your extension needs join functionality

---

### 7. **ExtensionStakeMixin**
Stake/unstake/withdraw functionality with phase-based waiting period.

**Provides:**
- Stake with token amount
- Unstake request
- Withdraw after waiting phases
- Minimum governance votes check
- Stake info tracking

**Requires:**
- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionVerificationMixin

**Parameters:**
- `stakeTokenAddress`: Token to stake
- `waitingPhases`: Phases to wait before withdrawal
- `minGovVotes`: Minimum governance votes required

**Use when:** Your extension needs staking functionality

---

## 📚 Usage Examples

### Example 1: Extension with Join

```solidity
contract MyJoinExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_,
        uint256 minGovVotes_
    )
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(
            factory_,
            joinTokenAddress_,
            waitingBlocks_,
            minGovVotes_
        )
    {}

    // Implement required score calculation
    function calculateScores() 
        public view override 
        returns (uint256 total, uint256[] memory scores) 
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            scores[i] = _joinInfo[_accounts[i]].amount;
            total += scores[i];
        }
    }

    function calculateScore(address account) 
        public view override 
        returns (uint256 total, uint256 score) 
    {
        (total, ) = calculateScores();
        score = _joinInfo[account].amount;
    }
}
```

### Example 2: Extension with Stake

```solidity
contract MyStakeExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionStakeMixin
{
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    )
        ExtensionCoreMixin(factory_)
        ExtensionStakeMixin(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {}

    // Implement required score calculation
    function calculateScores() 
        public view override 
        returns (uint256 total, uint256[] memory scores) 
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            scores[i] = _stakeInfo[_accounts[i]].amount;
            total += scores[i];
        }
    }

    function calculateScore(address account) 
        public view override 
        returns (uint256 total, uint256 score) 
    {
        (total, ) = calculateScores();
        score = _stakeInfo[account].amount;
    }
}
```

### Example 3: Custom Scoring Logic

```solidity
contract MyCustomExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    // ... constructor ...

    // Custom scoring: square root of joined amount
    function calculateScores() 
        public view override 
        returns (uint256 total, uint256[] memory scores) 
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            uint256 amount = _joinInfo[_accounts[i]].amount;
            scores[i] = sqrt(amount);  // Custom logic
            total += scores[i];
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        // ... sqrt implementation ...
    }
}
```

## 🎯 Mixin Selection Guide

**Need basic extension?**
→ `CoreMixin` + `AccountMixin` + `RewardMixin`

**Need join functionality?**
→ Add `VerificationMixin` + `JoinMixin`

**Need staking functionality?**
→ Add `VerificationMixin` + `StakeMixin`

**Need score-based rewards?**
→ Add `ScoreMixin` (implements reward calculation)

**Need custom reward logic?**
→ Use `RewardMixin` and implement `rewardByAccount()`

## 🔧 Creating Custom Mixins

You can create your own mixins following these principles:

1. **Single Responsibility**: Each mixin should do one thing well
2. **Composability**: Mixins should work together without conflicts
3. **Minimal Dependencies**: Only depend on necessary mixins
4. **Clear Interface**: Expose both internal helpers and public functions

```solidity
abstract contract MyCustomMixin is ExtensionCoreMixin {
    // State variables
    mapping(address => uint256) internal _myData;
    
    // Events
    event MyEvent(address indexed account, uint256 value);
    
    // Public functions
    function myPublicFunction() external {
        _myInternalLogic();
    }
    
    // Internal helpers (for composition)
    function _myInternalLogic() internal {
        _myData[msg.sender] = block.timestamp;
        emit MyEvent(msg.sender, block.timestamp);
    }
}
```

## 📋 Comparison with Original Design

| Aspect | Original | Mixin |
|--------|----------|-------|
| **Inheritance Depth** | 3 levels | 1 level (flat) |
| **Reusability** | Limited | High |
| **Customization** | Difficult | Easy |
| **Testing** | Complex | Simple (per mixin) |
| **Code Duplication** | Possible | Minimized |
| **Flexibility** | Low | High |

## 🚀 Migration Guide

### From Base/AutoScore/Join to Mixins:

**Before:**
```solidity
contract MyExtension is LOVE20ExtensionAutoScoreJoin {
    constructor(...) LOVE20ExtensionAutoScoreJoin(...) {}
    // Limited customization
}
```

**After:**
```solidity
contract MyExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    constructor(...) 
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(factory_, token_, blocks_, votes_)
    {}
    
    // Full customization - override any function
    function calculateScores() public view override returns (...) {
        // Your custom logic
    }
}
```

## 💡 Best Practices

1. **Always start with CoreMixin** - it's the foundation
2. **Add AccountMixin early** - most extensions track participants
3. **Choose between Join and Stake** - don't use both unless necessary
4. **Use ScoreMixin for proportional rewards** - or implement custom logic
5. **Override carefully** - call parent implementations when needed
6. **Test mixins independently** - easier debugging
7. **Document your composition** - explain why you chose specific mixins

## 🐛 Common Issues

### Issue: Constructor conflicts
```solidity
// ❌ Wrong - missing ExtensionCoreMixin constructor
contract Bad is ExtensionCoreMixin, ExtensionJoinMixin {
    constructor() {}  // Missing factory_ parameter!
}

// ✅ Correct
contract Good is ExtensionCoreMixin, ExtensionJoinMixin {
    constructor(address factory_, ...) 
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(factory_, ...)
    {}
}
```

### Issue: Missing implementation
```solidity
// ❌ Wrong - ScoreMixin requires implementation
contract Bad is ExtensionScoreMixin {
    // Missing calculateScores() and calculateScore()
}

// ✅ Correct
contract Good is ExtensionScoreMixin {
    function calculateScores() public view override returns (...) {
        // Implementation
    }
    function calculateScore(address) public view override returns (...) {
        // Implementation
    }
}
```

### Issue: Storage collision
```solidity
// ❌ Wrong - variable name collision
contract Bad is ExtensionAccountMixin {
    address[] internal _accounts;  // Already in AccountMixin!
}

// ✅ Correct - use different name or access parent's
contract Good is ExtensionAccountMixin {
    address[] internal _myCustomAccounts;  // Different name
}
```

## 📖 Further Reading

- [Solidity Documentation - Multiple Inheritance](https://docs.soliditylang.org/en/latest/contracts.html#multiple-inheritance-and-linearization)
- [OpenZeppelin - Access Control](https://docs.openzeppelin.com/contracts/4.x/access-control)
- [Design Patterns in Solidity](https://fravoll.github.io/solidity-patterns/)

---

## ✨ Summary

The mixin architecture provides:
- ✅ **Modularity**: Pick only what you need
- ✅ **Flexibility**: Easy to customize and extend
- ✅ **Maintainability**: Each mixin is independently testable
- ✅ **Reusability**: Compose different combinations
- ✅ **Clarity**: Single responsibility per mixin

Start building your custom extension by selecting the mixins that match your requirements!

