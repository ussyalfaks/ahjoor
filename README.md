# Ahjoor - Decentralized ROSCA Smart Contract

Ahjoor is a Cairo smart contract implementing a Rotating Savings and Credit Association (ROSCA) on Starknet. It enables groups of people to pool their money together and take turns receiving the collective sum, using STRK tokens for contributions and payouts.

## What is a ROSCA?

A Rotating Savings and Credit Association (ROSCA) is a group of individuals who agree to meet for a defined period to save and borrow together. In each meeting, the group's money is given to one member. This system is known by various names across cultures:
- **Ahjoor** (Nigeria)
- **Ajo/Esusu** (West Africa)
- **Susu** (Ghana/Caribbean)
- **Tanda** (Mexico)
- **Chit Fund** (India)

## Features

### Core Functionality
- **Group Creation**: Organizers can create ROSCA groups with predefined participant lists
- **STRK Contributions**: Participants contribute STRK tokens each round
- **Automated Payouts**: Recipients can claim their payout when it's their turn
- **Access Control**: Only pre-defined participants can contribute to groups
- **Admin Controls**: Contract owner can pause/unpause operations

### Security Features
- **STRK Integration**: Uses STRK tokens for reliable value transfer
- **Access Control**: Only authorized participants can interact with groups
- **Time-based Rounds**: Automatic round progression based on duration
- **OpenZeppelin Standards**: Implements Ownable and Pausable patterns

## Contract Architecture

### Main Components

1. **Group Management**
   - `create_group()`: Create a new ROSCA group with participant list
   - `get_group_info()`: Get group details
   - `get_group_count()`: Get total number of groups created

2. **Contributions & Payouts**
   - `contribute()`: Make STRK contribution for current round
   - `claim_payout()`: Claim payout when it's your turn

3. **View Functions**
   - `is_participant()`: Check if address is in group

4. **Admin Functions**
   - `pause()` / `unpause()`: Emergency controls
   - `transfer_ownership()`: Transfer contract ownership

### Data Structures

#### GroupInfo
```cairo
struct GroupInfo {
    name: ByteArray,
    description: ByteArray,
    organizer: ContractAddress,
    num_participants: u32,
    contribution_amount: u256,
    round_duration: u64,
    num_participants_stored: u32,
    current_round: u32,
    is_completed: bool,
    created_at: u64,
    last_payout_time: u64,
}
```

## Usage Flow

### 1. Group Creation
```cairo
let participant_addresses = array![address1, address2, address3];
let group_id = ahjoor.create_group(
    "My Savings Group",           // Group name
    "Monthly savings circle",     // Description
    3_u32,                        // Number of participants
    1000_u256,                    // 1000 STRK contribution per round
    604800_u64,                   // 7 days per round (in seconds)
    participant_addresses         // Pre-defined participant list
);
```

### 2. Contributing Each Round
```cairo
// First approve STRK spending
strk.approve(ahjoor_contract_address, contribution_amount);

// Then contribute
ahjoor.contribute(group_id);
```

### 3. Claiming Payouts
```cairo
ahjoor.claim_payout(group_id);  // Only current round recipient
```

## Events

The contract emits events for all major actions:
- `GroupCreated`: New group created
- `ContributionMade`: Participant made contribution
- `PayoutClaimed`: Recipient claimed payout
- `Paused` / `Unpaused`: Contract state changes
- `OwnershipTransferred`: Owner changes
- `Upgraded`: Contract upgrades

## Prerequisites

- **STRK Token**: Contract requires STRK token address during deployment
- **Starknet Wallet**: Participants need Starknet-compatible wallets
- **STRK Balance**: Participants must have sufficient STRK for contributions
- **STRK Approval**: Participants must approve contract to spend STRK

## Deployment

### Current Deployment (Sepolia Testnet)
- **Contract Address**: `0x056f0d4f9a0ff9e0cfe8016d230806cd6c3fc3d6fd129875e27a7d50b43a123b`
- **STRK Token Address**: `0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d`
- **Owner Address**: `0x6943f2231202f4f6f52ff6f0e52e393544f94d7d7c6d0ac0c4bdc6fc6be6cc3`
- **View on StarkScan**: [Contract](https://sepolia.starkscan.co/contract/0x056f0d4f9a0ff9e0cfe8016d230806cd6c3fc3d6fd129875e27a7d50b43a123b)

### Deploy Your Own
1. Build and deploy using the deployment script:
```bash
./deploy.sh
```

Or manually:
```bash
scarb build
sncast declare --contract-name AhjoorROSCA
sncast deploy --class-hash <class_hash> --constructor-calldata <strk_token_address> <owner_address>
```

## Testing

Run the comprehensive test suite:
```bash
scarb test
```

### Test Results
**All tests pass**: 11 passed, 0 failed, 0 skipped

### Test Coverage
✅ **Core Functionality**
- Group creation with parameters validation
- Access control (only pre-defined participants can contribute)
- Multiple groups support
- Group state management

✅ **Security & Validation**
- Input parameter validation (minimum participants, contribution amount, duration)
- Organizer verification (must be in participant list)
- Address count matching
- Proper error handling for unauthorized access

✅ **Contract Logic** 
- Group completion state tracking
- Round progression logic
- Participant identification
- Independent group state management

### Test Framework Features
- **Mock Contracts**: MockSTRK for testing token interactions
- **Cairo 1 Testing**: Uses `snforge_std` for advanced testing capabilities
- **Time Manipulation**: Block timestamp and caller address testing
- **Error Testing**: Comprehensive `#[should_panic]` validation

*Note: Some advanced tests requiring full ERC-20 token interaction cycles are documented in TEST_SUMMARY.md but not implemented due to test environment complexity.*

## Security Considerations

### Implemented Safeguards
- **Input Validation**: All parameters validated (minimum participants, contribution amounts, round duration)
- **Access Control**: Only pre-defined participants can contribute to groups
- **Ownership Pattern**: OpenZeppelin Ownable implementation for admin functions
- **Pausable Contract**: Owner can pause operations in emergencies
- **Overflow Protection**: Uses u256 for amounts and proper arithmetic
- **Time-based Rounds**: Enforced minimum round duration (24 hours)

### Potential Risks
- **Participant Commitment**: No enforcement if participants stop contributing mid-cycle
- **STRK Dependency**: Relies on STRK token contract security and availability
- **Centralized Pause**: Contract owner can pause all operations
- **Round Timing**: Fixed round duration may not suit all group preferences
- **No Partial Refunds**: If group fails, there's no built-in refund mechanism

## Development

### Building
```bash
scarb build
```

### Testing
```bash
scarb test
```

### Formatting
```bash
scarb fmt
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Roadmap

### Future Enhancements
- **Governance**: Participant voting on group decisions
- **Flexible Payouts**: Custom payout ordering (auction, lottery)
- **Multi-token Support**: Support for other stablecoins
- **Insurance**: Optional insurance against defaults
- **Mobile dApp**: User-friendly mobile interface
- **Analytics**: Group performance and statistics
- **Notifications**: Round reminders and updates

### Integration Opportunities
- **DeFi Yield**: Earn yield on pooled funds between rounds
- **Credit Scoring**: Build on-chain credit history
- **Cross-chain**: Bridge to other blockchain networks
- **Traditional Banking**: Fiat on/off ramps

## Support

For questions, issues, or contributions, please open an issue on the GitHub repository or contact the development team.
