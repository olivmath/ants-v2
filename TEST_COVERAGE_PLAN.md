# 📋 Test Coverage Plan - CryptoAnts

## Current Coverage: 35.14% Lines | 32.10% Statements | 11.11% Branches
## Target: 100% Coverage

---

## 🎯 Function Coverage Analysis

### 1. **setEggPrice** (line 70-72) - NOT TESTED
**Branches to cover:**
- ✅ Owner can set price
- ❌ Non-owner cannot set price (Ownable revert)
- ❌ Price can be set to 0
- ❌ Price can be set to max uint256

**Tests needed:**
- `testSetEggPriceAsOwner` (BDD)
- `testSetEggPriceAsNonOwner` (BDD - should revert)
- `testSetEggPriceToZero` (Fuzz)
- `testSetEggPriceToMaxUint` (Fuzz)

---

### 2. **buyEggs** (line 74-104) - PARTIALLY TESTED
**Branches to cover:**
- ✅ User sends exact amount
- ✅ User sends excess amount (refund path tested)
- ❌ User sends insufficient amount (should revert)
- ❌ Mint fails (catch block not tested)
- ❌ Refund fails (catch block in line 93-100 not tested)
- ❌ Buy 0 eggs
- ❌ Buy max uint256 eggs (overflow)

**Tests needed:**
- `testBuyEggsInsufficientEther` (BDD - revert)
- `testBuyEggsRefundFails` (BDD - malicious contract)
- `testBuyEggsZeroAmount` (Edge case)
- `testBuyEggsFuzz` (Fuzz - random amounts)

---

### 3. **createAnt** (line 106-125) - PARTIALLY TESTED
**Branches to cover:**
- ✅ User has 1 egg and creates ant
- ❌ User has 0 eggs (should revert)
- ❌ BurnFrom fails (catch block not tested)
- ❌ Create multiple ants sequentially (test antsCreated counter)
- ❌ First ant created has ID 1

**Tests needed:**
- `testCreateAntWithoutEggs` (BDD - revert)
- `testCreateAntBurnFails` (BDD)
- `testCreateMultipleAnts` (BDD)
- `testFirstAntHasIdOne` (Unit)

---

### 4. **sellAnt** (line 127-144) - PARTIALLY TESTED
**Branches to cover:**
- ✅ Owner sells alive ant
- ✅ Owner cannot sell dead ant
- ✅ NFT is burned after sell
- ❌ Non-owner cannot sell ant (Unauthorized revert)
- ❌ Payment fails (catch block line 132-138 not tested)
- ❌ Contract has insufficient balance

**Tests needed:**
- `testSellAntAsNonOwner` (BDD - revert)
- `testSellAntPaymentFails` (BDD - malicious contract)
- `testSellAntInsufficientContractBalance` (BDD)

---

### 5. **layEggs** (line 146-182) - PARTIALLY TESTED
**Branches to cover:**
- ✅ Ant lays eggs successfully
- ❌ Non-owner calls layEggs (Unauthorized)
- ❌ Dead ant cannot lay eggs (AntIsDead) - **partially tested in BDD files**
- ❌ Cooldown not met (CooldownNotMet) - **partially tested in BDD files**
- ❌ Ant dies (10% chance) - **partially tested in BDD files**
- ❌ Ant lays 0 eggs (edge case)
- ❌ Mint fails in layEggs (catch block not tested)
- ❌ Old ant initialization (line 152-155 backward compatibility)

**Tests needed:**
- `testLayEggsAsNonOwner` (BDD - revert)
- `testLayEggsOldAntInitialization` (BDD - backward compat)
- `testLayEggsMintFails` (BDD)
- `testLayEggsZeroEggs` (Edge case)

---

### 6. **Helper Functions** - NOT TESTED
**_generateRandomNumber** (line 189-191)
- ❌ Different antIds produce different numbers
- ❌ Different nonces produce different numbers
- ❌ Same inputs produce same output (deterministic)

**_getNormalDistributedEggs** (line 197-201)
- ❌ Returns 0-20 range
- ❌ Distribution peaks around 10
- ❌ Never exceeds 20

**Tests needed:**
- `testGenerateRandomNumberDeterministic` (Unit)
- `testGetNormalDistributedEggsRange` (Fuzz)
- `testGetNormalDistributedEggsDistribution` (Fuzz)

---

### 7. **View Functions** - PARTIALLY TESTED
**getContractBalance** (line 203-205) - NOT TESTED
**getAntsCreated** (line 207-209) - TESTED

**Tests needed:**
- `testGetContractBalance` (Unit)

---

## 🔀 Edge Cases & Integration Tests

### Reentrancy
- ❌ Test reentrancy protection on buyEggs
- ❌ Test reentrancy protection on layEggs

### Events
- ❌ EggsBought event emitted correctly
- ❌ AntCreated event emitted correctly
- ❌ AntSold event emitted correctly
- ❌ EggsLaid event emitted correctly
- ❌ AntDied event emitted correctly

### State Transitions
- ❌ Ant lifecycle: created → lays eggs → dies
- ❌ Multiple users interacting
- ❌ Sequential operations

---

## 🎲 Fuzz Testing Strategy

### 1. **buyEggs Fuzz**
```solidity
function testFuzz_BuyEggs(uint256 amount, uint256 payment) public {
  // Bound inputs to reasonable ranges
  // Test: correct amount minted, correct refund
}
```

### 2. **Randomness Distribution Fuzz**
```solidity
function testFuzz_EggDistribution(uint256 seed) public {
  // Test: eggs always in 0-20 range
  // Test: distribution roughly normal
}
```

### 3. **Price Setting Fuzz**
```solidity
function testFuzz_SetEggPrice(uint256 newPrice) public {
  // Test: price updates correctly
  // Test: no overflow issues
}
```

---

## 🔐 Formal Verification with Halmos

### Invariants to Prove

1. **Ant ID Uniqueness**
```solidity
// INVARIANT: Each ant has a unique, sequential ID
// antsCreated always increases by 1
// No ant ID can be skipped
```

2. **Total Supply Conservation**
```solidity
// INVARIANT: Sum of all user egg balances = total eggs minted
// No eggs created/destroyed except through buyEggs/createAnt/layEggs
```

3. **Ant State Validity**
```solidity
// INVARIANT: Dead ants cannot become alive
// If ant.isAlive == false, it stays false forever
```

4. **Economic Invariants**
```solidity
// INVARIANT: User pays eggPrice per egg (plus refund)
// Contract balance = payments - refunds - ant sales
```

5. **Cooldown Enforcement**
```solidity
// INVARIANT: Egg laying respects cooldown
// ant.lastEggLayTime + EGG_LAY_COOLDOWN <= block.timestamp
```

---

## 📝 Implementation Checklist

### BDD Tests (test/e2e/)
- [ ] Implement `testDeadAntCannotLayEggs` ✍️
- [ ] Implement `testLayEggsCooldownEnforcement` ✍️
- [ ] Implement `testAntCanDieWhenLayingEggs` ✍️
- [ ] Implement `testExcessEthRefundedWhenBuyingEggs` ✍️
- [ ] Implement `testCannotSellDeadAnt` ✍️
- [ ] Add `testSetEggPriceAsOwner`
- [ ] Add `testSetEggPriceAsNonOwner`
- [ ] Add `testBuyEggsInsufficientEther`
- [ ] Add `testCreateAntWithoutEggs`
- [ ] Add `testSellAntAsNonOwner`
- [ ] Add `testLayEggsAsNonOwner`

### Fuzz Tests (test/fuzz/)
- [ ] Create `CryptoAntsFuzz.t.sol`
- [ ] Add `testFuzz_BuyEggs`
- [ ] Add `testFuzz_EggDistribution`
- [ ] Add `testFuzz_SetEggPrice`
- [ ] Add `testFuzz_AntCreation`

### Formal Verification (test/formal/)
- [ ] Setup Halmos
- [ ] Create `CryptoAntsFormal.t.sol`
- [ ] Prove ant ID uniqueness invariant
- [ ] Prove egg supply conservation
- [ ] Prove ant state validity
- [ ] Prove economic invariants
- [ ] Prove cooldown enforcement

### Unit Tests (test/unit/)
- [ ] Create `CryptoAntsUnit.t.sol`
- [ ] Test helper functions
- [ ] Test view functions
- [ ] Test events
- [ ] Test edge cases

---

## 🎯 Priority Order

1. **HIGH**: Implement missing BDD tests (5 files)
2. **HIGH**: Add critical revert cases (Unauthorized, InsufficientEggs, etc.)
3. **MEDIUM**: Add fuzz tests for randomness and pricing
4. **MEDIUM**: Add event emission tests
5. **LOW**: Setup Halmos formal verification
6. **LOW**: Prove invariants

---

## 📊 Expected Final Coverage

After implementation:
- **Lines**: 95-100%
- **Statements**: 95-100%
- **Branches**: 90-95%
- **Functions**: 100%
