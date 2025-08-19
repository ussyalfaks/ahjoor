#[starknet::contract]
pub mod AhjoorROSCA {
    use crate::interfaces::iahjoor_rosca::IAhjoorROSCA;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::structs::group_info::GroupInfo;
    use crate::events::ahjoor_events::{
        GroupCreated, ContributionMade, PayoutClaimed, Paused, Unpaused, 
        OwnershipTransferred, Upgraded
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        // OpenZeppelin-style state variables
        owner: ContractAddress,
        paused: bool,
        
        // ROSCA specific storage
        usdc_token: ContractAddress,
        group_counter: u256,
        groups: Map<u256, GroupInfo>,
        participant_addresses: Map<(u256, u32), ContractAddress>,
        contributions: Map<(u256, ContractAddress, u32), bool>,
        total_pool: Map<u256, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GroupCreated: GroupCreated,
        ContributionMade: ContributionMade,
        PayoutClaimed: PayoutClaimed,
        Paused: Paused,
        Unpaused: Unpaused,
        OwnershipTransferred: OwnershipTransferred,
        Upgraded: Upgraded,
    }

    #[constructor]
    fn constructor(ref self: ContractState, usdc_token_address: ContractAddress, owner: ContractAddress) {
        self.usdc_token.write(usdc_token_address);
        self.group_counter.write(0);
        self.owner.write(owner);
        self.paused.write(false);
        
        self.emit(OwnershipTransferred {
            previous_owner: Zero::zero(),
            new_owner: owner,
        });
    }

    // Internal functions (OpenZeppelin style)
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Ownable: caller not owner');
        }

        fn assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), 'Pausable: paused');
        }

        fn assert_paused(self: @ContractState) {
            assert(self.paused.read(), 'Pausable: not paused');
        }
    }

    #[abi(embed_v0)]
    impl AhjoorROSCAImpl of IAhjoorROSCA<ContractState> {
        fn create_group(
            ref self: ContractState,
            name: ByteArray,
            description: ByteArray,
            num_participants: u32,
            contribution_amount: u256,
            round_duration: u64,
            participant_addresses: Array<ContractAddress>
        ) -> u256 {
            // Check if contract is paused
            self.assert_not_paused();
            
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Validate inputs
            assert(num_participants >= 2, 'Min 2 participants required');
            assert(num_participants <= 50, 'Max 50 participants allowed');
            assert(contribution_amount > 0, 'Contribution must be > 0');
            assert(round_duration >= 86400, 'Min 1 day round duration');
            assert(participant_addresses.len() == num_participants, 'Addresses count mismatch');
            
            // Verify organizer is in participant list
            let mut found_organizer = false;
            let mut i = 0;
            while i < participant_addresses.len() {
                if *participant_addresses.at(i) == caller {
                    found_organizer = true;
                    break;
                }
                i += 1;
            };
            assert(found_organizer, 'Organizer not in list');
            
            let group_id = self.group_counter.read() + 1;
            self.group_counter.write(group_id);
            
            // Store participant addresses
            let mut j = 0;
            while j < participant_addresses.len() {
                self.participant_addresses.write((group_id, j), *participant_addresses.at(j));
                j += 1;
            };
            
            let group_info = GroupInfo {
                name: name.clone(),
                description: description.clone(),
                organizer: caller,
                num_participants,
                contribution_amount,
                round_duration,
                num_participants_stored: num_participants,
                current_round: 1,
                is_completed: false,
                created_at: current_time,
                last_payout_time: 0,
            };
            
            self.groups.write(group_id, group_info);
            
            self.emit(GroupCreated {
                group_id,
                organizer: caller,
                name,
                num_participants,
                contribution_amount,
            });
            
            group_id
        }

        fn contribute(ref self: ContractState, group_id: u256) {
            // Check if contract is paused
            self.assert_not_paused();
            
            let caller = get_caller_address();
            let group = self.groups.read(group_id);
            
            // Validate group exists and is active
            assert(group.organizer.is_non_zero(), 'Group does not exist');
            assert(!group.is_completed, 'Group is completed');
            
            // Verify caller is a participant
            assert(self.is_participant(group_id, caller), 'Not a participant');
            
            // Check if already contributed for current round
            let has_contributed = self.contributions.read((group_id, caller, group.current_round));
            assert(!has_contributed, 'Already contributed this round');
            
            // Transfer USDC from participant to contract
            let usdc_address = self.usdc_token.read();
            let usdc = IERC20Dispatcher { contract_address: usdc_address };
            let success = usdc.transfer_from(caller, get_contract_address(), group.contribution_amount);
            assert(success, 'USDC transfer failed');
            
            // Mark contribution
            self.contributions.write((group_id, caller, group.current_round), true);
            
            // Update total pool
            let current_pool = self.total_pool.read(group_id);
            self.total_pool.write(group_id, current_pool + group.contribution_amount);
            
            self.emit(ContributionMade {
                group_id,
                participant: caller,
                amount: group.contribution_amount,
                round: group.current_round,
            });
        }

        fn claim_payout(ref self: ContractState, group_id: u256) {
            // Check if contract is paused
            self.assert_not_paused();
            
            let caller = get_caller_address();
            let group = self.groups.read(group_id);
            
            // Validate group exists and is active
            assert(group.organizer.is_non_zero(), 'Group does not exist');
            assert(!group.is_completed, 'Group is completed');
            
            // Check if it's time for payout (all participants contributed)
            let expected_pool = group.contribution_amount * group.num_participants.into();
            let current_pool = self.total_pool.read(group_id);
            assert(current_pool >= expected_pool, 'Not all contributed');
            
            // Get current round recipient (based on payout order)
            let recipient_index = (group.current_round - 1) % group.num_participants;
            let current_recipient = self.participant_addresses.read((group_id, recipient_index));
            assert(current_recipient == caller, 'Not your turn for payout');
            
            // Check timing - ensure round duration has passed since last payout
            let current_time = get_block_timestamp();
            if group.last_payout_time > 0 {
                assert(current_time >= group.last_payout_time + group.round_duration, 'Round duration not elapsed');
            }
            
            // Transfer payout
            let payout_amount = group.contribution_amount * group.num_participants.into();
            let usdc_address = self.usdc_token.read();
            let usdc = IERC20Dispatcher { contract_address: usdc_address };
            let success = usdc.transfer(caller, payout_amount);
            assert(success, 'USDC payout failed');
            
            // Update pool
            self.total_pool.write(group_id, current_pool - payout_amount);
            
            // Update group state
            let updated_group = GroupInfo {
                name: group.name,
                description: group.description,
                organizer: group.organizer,
                num_participants: group.num_participants,
                contribution_amount: group.contribution_amount,
                round_duration: group.round_duration,
                num_participants_stored: group.num_participants_stored,
                current_round: group.current_round + 1,
                is_completed: if group.current_round + 1 > group.num_participants { true } else { false },
                created_at: group.created_at,
                last_payout_time: current_time,
            };
            
            self.groups.write(group_id, updated_group);
            
            self.emit(PayoutClaimed {
                group_id,
                recipient: caller,
                amount: payout_amount,
                round: group.current_round,
            });
        }

        fn get_group_info(self: @ContractState, group_id: u256) -> GroupInfo {
            self.groups.read(group_id)
        }

        fn is_participant(self: @ContractState, group_id: u256, address: ContractAddress) -> bool {
            let group = self.groups.read(group_id);
            let mut i = 0;
            while i < group.num_participants {
                if self.participant_addresses.read((group_id, i)) == address {
                    return true;
                }
                i += 1;
            };
            false
        }

        fn get_group_count(self: @ContractState) -> u256 {
            self.group_counter.read()
        }
        
        // Admin functions (OpenZeppelin style)
        fn pause(ref self: ContractState) {
            self.assert_only_owner();
            self.assert_not_paused();
            self.paused.write(true);
            
            self.emit(Paused {
                account: get_caller_address(),
            });
        }

        fn unpause(ref self: ContractState) {
            self.assert_only_owner();
            self.assert_paused();
            self.paused.write(false);
            
            self.emit(Unpaused {
                account: get_caller_address(),
            });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.assert_only_owner();
            assert(!new_owner.is_zero(), 'Ownable: new owner is zero');
            
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);
            
            self.emit(OwnershipTransferred {
                previous_owner,
                new_owner,
            });
        }

        fn renounce_ownership(ref self: ContractState) {
            self.assert_only_owner();
            
            let previous_owner = self.owner.read();
            self.owner.write(Zero::zero());
            
            self.emit(OwnershipTransferred {
                previous_owner,
                new_owner: Zero::zero(),
            });
        }

        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.assert_only_owner();
            // Note: Actual upgrade implementation would use replace_class_syscall
            // This is a placeholder for access control testing
            
            self.emit(Upgraded {
                new_class_hash,
            });
        }
        
        // View functions
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
}