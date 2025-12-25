# 🧪 Test Organization

This project uses a comprehensive testing strategy with 4 types of tests:

## 📁 Directory Structure

```
test/
├── e2e/          # End-to-End / Integration Tests (BDD)
├── fuzz/         # Property-Based / Fuzz Tests
├── unit/         # Unit Tests (TDD / Coverage)
├── formal/       # Formal Verification (Halmos)
└── README.md     # This file
```

---

## 🔄 1. E2E Tests (End-to-End / BDD)

**Location**: `test/e2e/`

**Purpose**: Test complete user flows and business logic

**Style**: Behavior-Driven Development (Given/When/Then)

**Run**:
```bash
# Run all E2E tests
forge test --match-path "test/e2e/*.t.sol"

# Run specific E2E test
forge test --match-path "test/e2e/CryptoAnts.t.sol"

# Run with gas report
forge test --match-path "test/e2e/*.t.sol" --gas-report
```

**Tests**:
- ✅ `CryptoAnts.t.sol` - Main E2E flows
- ✅ `DeadAntCannotLayEggs.t.sol` - Death mechanics
- ✅ `LayEggsCooldownEnforcement.t.sol` - Cooldown logic
- ✅ `AntCanDieWhenLayingEggs.t.sol` - Random death
- ✅ `ExcessEthRefundedWhenBuyingEggs.t.sol` - Payment refunds
- ✅ `CannotSellDeadAnt.t.sol` - Dead ant restrictions

---

## 🎲 2. Fuzz Tests (Property-Based)

**Location**: `test/fuzz/`

**Purpose**: Test properties with random inputs to find edge cases

**Style**: Property-based testing with bounded random inputs

**Run**:
```bash
# Run fuzz tests (default 256 runs)
forge test --match-path "test/fuzz/*.t.sol"

# Run with more iterations
forge test --match-path "test/fuzz/*.t.sol" --fuzz-runs 1000

# Run with seed for reproducibility
forge test --match-path "test/fuzz/*.t.sol" --fuzz-seed 42
```

**Tests**:
- ✅ `testFuzz_BuyEggs` - Random amounts & payments
- ✅ `testFuzz_SetEggPrice` - Random prices
- ✅ `testFuzz_EggDistributionRange` - Egg count bounds
- ✅ `testFuzz_CreateAntWithVaryingEggs` - Variable ant creation
- ✅ `testFuzz_RandomnessVariation` - RNG distribution

**Configure** (`foundry.toml`):
```toml
[fuzz]
runs = 256  # Number of fuzz runs
max_test_rejects = 65536  # Max rejections before failing
```

---

## ✅ 3. Unit Tests (TDD / Coverage)

**Location**: `test/unit/`

**Purpose**: Test individual functions and achieve 100% code coverage

**Style**: Test-Driven Development - one test per function/branch

**Run**:
```bash
# Run all unit tests
forge test --match-path "test/unit/*.t.sol"

# Run with coverage
forge coverage --match-path "test/unit/*.t.sol"

# Generate detailed coverage report
forge coverage --report lcov
genhtml lcov.info -o coverage/
```

**Tests** (32 tests):
- `setEggPrice` (4 tests)
- `buyEggs` (4 tests)
- `createAnt` (6 tests)
- `sellAnt` (3 tests)
- `layEggs` (3 tests)
- View functions (2 tests)
- Edge cases (3 tests)

**Coverage Goal**: 95%+ lines, 90%+ branches

---

## 🔐 4. Formal Verification (Halmos)

**Location**: `test/formal/`

**Purpose**: Mathematically prove contract invariants hold under all conditions

**Style**: Symbolic execution with formal proofs

**Setup**:
```bash
# Install Halmos
pip install halmos

# Or use pipx (recommended)
pipx install halmos
```

**Run**:
```bash
# Run all formal verification tests
halmos --contract CryptoAntsFormalTest

# Run specific invariant
halmos --contract CryptoAntsFormalTest --function check_AntIdUniqueness

# With debugging
halmos --contract CryptoAntsFormalTest -v

# With custom loop bounds
halmos --contract CryptoAntsFormalTest --loop 5
```

**Invariants Proven** (7 invariants):
1. ✅ **Ant ID Uniqueness** - IDs are sequential and unique
2. ✅ **Dead Ants Stay Dead** - No resurrection
3. ✅ **Egg Conservation** - Supply accounting
4. ✅ **Cooldown Enforcement** - Time-based restrictions
5. ✅ **Ownership Enforcement** - Access control
6. ✅ **Egg Laying Range** - Output bounds [0, 20]
7. ✅ **Payment Correctness** - Economic invariant

**Configure** (`.halmos.toml`):
```toml
loop = 3
width = 256
depth = 100
```

---

## 📊 Running All Tests

```bash
# Run everything
forge test

# Run with coverage
forge coverage

# Run specific category
forge test --match-path "test/e2e/*.t.sol"
forge test --match-path "test/fuzz/*.t.sol"
forge test --match-path "test/unit/*.t.sol"

# Run formal verification separately
halmos --contract CryptoAntsFormalTest
```

---

## 📈 Test Metrics

| Category | Tests | Lines | Branches | Purpose |
|----------|-------|-------|----------|---------|
| **E2E** | 9 | ~500 | High | User flows |
| **Fuzz** | 5 | ~200 | High | Edge cases |
| **Unit** | 32 | ~400 | 100% | Coverage |
| **Formal** | 7 | ~300 | Proofs | Invariants |
| **TOTAL** | **53** | **~1400** | **95%+** | Complete |

---

## 🎯 Testing Strategy

### When to Use Each Type

**E2E**: Complex multi-step flows
```solidity
// Example: Full user journey
testBuyEggAndCreateNewAnt()
```

**Fuzz**: Numerical bounds and edge cases
```solidity
// Example: Random inputs
testFuzz_BuyEggs(uint256 amount, uint256 payment)
```

**Unit**: Individual function branches
```solidity
// Example: Single branch
test_SetEggPrice_AsNonOwner_ShouldRevert()
```

**Formal**: Critical invariants
```solidity
// Example: Mathematical proof
check_AntIdUniqueness()
```

---

## 🐛 Debugging Failed Tests

```bash
# Verbose output
forge test -vv

# Very verbose (shows traces)
forge test -vvv

# Maximum verbosity (shows everything)
forge test -vvvv

# Specific test
forge test --match-test testBuyEggs -vvvv

# Gas profiling
forge test --gas-report

# Coverage with detailed output
forge coverage --report debug > coverage.txt
```

---

## 🚀 CI/CD Integration

```yaml
# .github/workflows/test.yml
- name: Run all tests
  run: |
    forge test
    forge coverage
    halmos --contract CryptoAntsFormalTest
```

---

## 📝 Writing New Tests

### E2E Test Template
```solidity
function testNewFeature() public {
  // Given: setup
  // When: action
  // Then: assertions
}
```

### Fuzz Test Template
```solidity
function testFuzz_NewFeature(uint256 input) public {
  input = bound(input, min, max);
  // Test property
}
```

### Unit Test Template
```solidity
function test_Function_Condition() public {
  // Arrange
  // Act
  // Assert
}
```

### Formal Test Template
```solidity
function check_Invariant() public {
  // Setup symbolic inputs
  // Execute operations
  // Assert invariant holds
}
```

---

## 📚 References

- [Foundry Testing](https://book.getfoundry.sh/forge/tests)
- [Fuzz Testing](https://book.getfoundry.sh/forge/fuzz-testing)
- [Halmos](https://github.com/a16z/halmos)
- [Coverage Reports](https://book.getfoundry.sh/reference/forge/forge-coverage)
