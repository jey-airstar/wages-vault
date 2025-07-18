# Wages Vault Smart Contract

A time-locked salary release system built on the Stacks blockchain using Clarity smart contracts. This contract enables employers to deposit employee salaries with automatic time-lock mechanisms, ensuring secure and scheduled wage distribution.

## 🚀 Features

- **Time-locked Releases**: Salaries are locked for specified intervals before becoming claimable
- **Multi-employee Support**: Manage multiple employees with individual salary configurations
- **Secure Deposits**: Funds are held securely in the contract until release conditions are met
- **Emergency Controls**: Employers can withdraw unclaimed deposits before release time
- **Transparent Tracking**: Complete visibility of deposits, releases, and balances
- **Access Control**: Role-based permissions for employers and employees

## 📋 Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Functions](#functions)
- [Data Structures](#data-structures)
- [Security Features](#security-features)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## 🛠 Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Stacks CLI](https://docs.stacks.co/docs/stacks-cli) - For deployment and interaction

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd wages-vault
```

2. Initialize Clarinet project:
```bash
clarinet new wages-vault
cd wages-vault
```

3. Add the contract to your `Clarinet.toml`:
```toml
[contracts.wages-vault]
path = "contracts/wages-vault.clar"
```

4. Run tests:
```bash
clarinet test
```

## 💼 Usage

### Basic Workflow

1. **Register Employee**: Employer registers an employee with salary details
2. **Deposit Salary**: Employer deposits funds for the employee
3. **Wait for Time Lock**: Funds remain locked for the specified interval
4. **Claim Salary**: Employee claims their salary after the time lock expires

### Example Usage

```javascript
// Register an employee
await callPublicFunction({
  contractName: 'wages-vault',
  functionName: 'register-employee',
  functionArgs: [
    principalCV('SP2...employee-address'),
    uintCV(1000000), // 1 STX salary
    uintCV(144)      // 144 blocks (~1 day) release interval
  ]
});

// Deposit salary
await callPublicFunction({
  contractName: 'wages-vault',
  functionName: 'deposit-salary',
  functionArgs: [
    principalCV('SP2...employee-address'),
    uintCV(1000000) // 1 STX
  ]
});

// Claim salary (after time lock expires)
await callPublicFunction({
  contractName: 'wages-vault',
  functionName: 'claim-salary',
  functionArgs: [
    uintCV(1) // deposit ID
  ]
});
```

## 📚 Functions

### Public Functions

#### `register-employee`
Registers a new employee with salary configuration.

**Parameters:**
- `employee` (principal): Employee's Stacks address
- `salary-amount` (uint): Default salary amount in microSTX
- `release-interval` (uint): Time lock duration in blocks

**Returns:** `(ok true)` on success

#### `deposit-salary`
Deposits salary funds for an employee with automatic time-locking.

**Parameters:**
- `employee` (principal): Employee's address
- `amount` (uint): Salary amount in microSTX

**Returns:** `(ok deposit-id)` - unique deposit identifier

#### `claim-salary`
Allows employees to claim their salary after the time lock expires.

**Parameters:**
- `deposit-id` (uint): Unique deposit identifier

**Returns:** `(ok amount)` - claimed amount

#### `emergency-withdraw`
Enables employers to withdraw unclaimed deposits before release time.

**Parameters:**
- `employee` (principal): Employee's address
- `deposit-id` (uint): Deposit identifier

**Returns:** `(ok amount)` - withdrawn amount

#### `deactivate-employee`
Deactivates an employee (prevents new deposits).

**Parameters:**
- `employee` (principal): Employee's address

**Returns:** `(ok true)` on success

### Read-only Functions

#### `get-employee-info`
Returns employee configuration and statistics.

#### `get-salary-deposit`
Returns details of a specific salary deposit.

#### `is-salary-ready`
Checks if a salary deposit is ready for claiming.

#### `get-available-salary`
Returns the total unclaimed salary for an employee.

#### `get-contract-balance`
Returns the contract's total STX balance.

## 📊 Data Structures

### Employee Record
```clarity
{
  employer: principal,
  salary-amount: uint,
  release-interval: uint,
  last-release-block: uint,
  total-deposited: uint,
  total-released: uint,
  active: bool
}
```

### Salary Deposit
```clarity
{
  employer: principal,
  amount: uint,
  deposit-block: uint,
  release-block: uint,
  released: bool
}
```

## 🔒 Security Features

### Access Control
- **Employer Authorization**: Only registered employers can deposit for their employees
- **Employee Authorization**: Only employees can claim their own salaries
- **Contract Owner**: Emergency pause/unpause functionality

### Time Lock Mechanism
- **Block-based Timing**: Uses Stacks block height for reliable time-locking
- **Immutable Delays**: Release times cannot be modified after deposit
- **Atomic Operations**: All state changes happen atomically

### Fund Security
- **Contract Custody**: Funds are held securely in the contract
- **Double-spend Prevention**: Each deposit can only be claimed once
- **Emergency Recovery**: Employers can recover unclaimed funds before release

## 🧪 Testing

### Unit Tests

Create test files in the `tests/` directory:

```typescript
// tests/wages-vault_test.ts
import { assertEquals } from "https://deno.land/std/testing/asserts.ts";
import { Clarinet, Tx, Chain, Account, types } from "https://deno.land/x/clarinet/index.ts";

Clarinet.test({
  name: "Can register employee",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const employer = accounts.get("wallet_1")!;
    const employee = accounts.get("wallet_2")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("wages-vault", "register-employee", [
        types.principal(employee.address),
        types.uint(1000000),
        types.uint(144)
      ], employer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, "(ok true)");
  }
});
```

### Integration Tests

Test the complete workflow:

```typescript
Clarinet.test({
  name: "Full salary cycle",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Register -> Deposit -> Wait -> Claim
    // Test implementation here
  }
});
```

## 🔧 Configuration

### Time Intervals
- **Blocks per Day**: ~144 blocks (10 minutes per block)
- **Blocks per Week**: ~1,008 blocks
- **Blocks per Month**: ~4,320 blocks

### Recommended Settings
- **Daily Salary**: 144 blocks
- **Weekly Salary**: 1,008 blocks
- **Monthly Salary**: 4,320 blocks

## 📈 Gas Costs

Estimated transaction costs:
- **Register Employee**: ~0.001 STX
- **Deposit Salary**: ~0.002 STX + deposit amount
- **Claim Salary**: ~0.001 STX
- **Emergency Withdraw**: ~0.001 STX

## 🚨 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Contract is paused |
| u101 | `err-not-found` | Employee or deposit not found |
| u102 | `err-already-exists` | Employee already registered |
| u103 | `err-insufficient-funds` | Invalid amount |
| u104 | `err-not-ready` | Time lock not expired |
| u105 | `err-already-released` | Already claimed/withdrawn |
| u106 | `err-unauthorized` | Access d
---

**Built with ❤️ on Stacks Blockchain**