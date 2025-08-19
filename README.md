# Ahjoor - Decentralized ROSCA Smart Contract

Ahjoor is a Cairo smart contract implementing a Rotating Savings and Credit Association (ROSCA) on Starknet. It enables groups of people to pool their money together and take turns receiving the collective sum, using USDC as the stablecoin.

## What is a ROSCA?

A Rotating Savings and Credit Association (ROSCA) is a group of individuals who agree to meet for a defined period to save and borrow together. In each meeting, the group's money is given to one member. This system is known by various names across cultures:
- **Ahjoor** (Nigeria)
- **Ajo/Esusu** (West Africa)
- **Susu** (Ghana/Caribbean)
- **Tanda** (Mexico)
- **Chit Fund** (India)

## Features

### Core Functionality
- **Group Creation**: Organizers can create ROSCA groups with customizable parameters
- **Participant Management**: Users can join groups before they start
- **Round-based Contributions**: Participants contribute USDC each round
- **Automated Payouts**: Recipients can claim their payout when it's their turn
- **Emergency Withdrawals**: Organizers can terminate groups and refund participants

### Security Features
- **USDC Integration**: Uses established stablecoin for reliable value transfer
- **Access Control**: Only authorized participants can interact with groups
- **Time-based Rounds**: Automatic round progression based on duration
- **Emergency Safeguards**: Organizer can halt operations if needed

## Contract Architecture

### Main Components

1. **Group Management**
   - `create_group()`: Create a new ROSCA group
   - `join_group()`: Join an existing group
   - `start_group()`: Begin the contribution rounds

2. **Contributions & Payouts**
   - `contribute()`: Make USDC contribution for current round
   - `claim_payout()`: Claim payout when it's your turn
   - `emergency_withdraw()`: Emergency group termination

3. **View Functions**
   - `get_group_info()`: Get group details
   - `get_participant_info()`: Get participant status
   - `get_current_recipient()`: See who receives payout this round
   - `is_participant()`: Check if address is in group

### Data Structures

#### GroupInfo
```cairo
struct GroupInfo {
    name: felt252,
    organizer: ContractAddress,
    contribution_amount: u256,
    max_participants: u32,
    current_participants: u32,
    round_duration: u64,
    current_round: u32,
    total_rounds: u32,
    is_active: bool,
    is_started: bool,
    created_at: u64,
    last_round_start: u64,
}
```

#### ParticipantInfo
```cairo
struct ParticipantInfo {
    address: ContractAddress,
    join_timestamp: u64,
    has_contributed_current_round: bool,
    has_received_payout: bool,
    payout_round: u32,
    total_contributed: u256,
}
```

## Usage Flow

### 1. Group Creation
```cairo
let group_id = ahjoor.create_group(
    'My Savings Group',    // Group name
    1000_u256,            // 1000 USDC contribution per round
    10_u32,               // Maximum 10 participants
    604800_u64            // 7 days per round (in seconds)
);
```

### 2. Joining Groups
```cairo
ahjoor.join_group(group_id);
```

### 3. Starting the Group
```cairo
ahjoor.start_group(group_id);  // Only organizer can call this
```

### 4. Contributing Each Round
```cairo
// First approve USDC spending
usdc.approve(ahjoor_contract_address, contribution_amount);

// Then contribute
ahjoor.contribute(group_id);
```

### 5. Claiming Payouts
```cairo
ahjoor.claim_payout(group_id);  // Only current round recipient
```

## Events

The contract emits events for all major actions:
- `GroupCreated`: New group created
- `ParticipantJoined`: User joined group
- `GroupStarted`: Group began operations
- `ContributionMade`: Participant made contribution
- `PayoutClaimed`: Recipient claimed payout
- `RoundAdvanced`: New round started with new recipient

## Prerequisites

- **USDC Token**: Contract requires USDC token address during deployment
- **Starknet Wallet**: Participants need Starknet-compatible wallets
- **USDC Balance**: Participants must have sufficient USDC for contributions
- **USDC Approval**: Participants must approve contract to spend USDC

## Deployment

1. Deploy USDC token contract (or use existing)
2. Deploy Ahjoor contract with USDC address:
```bash
starknet deploy --contract ahjoor --inputs <usdc_token_address>
```

## Testing

Run the comprehensive test suite:
```bash
scarb test
```

Tests cover:
- Group creation and validation
- Participant joining and management
- Group starting requirements
- Contribution mechanics
- Payout distribution
- Error conditions and edge cases

## Security Considerations

### Implemented Safeguards
- Input validation on all parameters
- Access control for sensitive operations
- Overflow protection with u256 amounts
- Emergency withdrawal mechanism
- Time-based round progression

### Potential Risks
- **Organizer Trust**: Organizers have emergency withdrawal power
- **Participant Commitment**: No enforcement if participants stop contributing
- **USDC Dependency**: Relies on USDC token contract security
- **Round Timing**: Automatic progression may not suit all groups

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
