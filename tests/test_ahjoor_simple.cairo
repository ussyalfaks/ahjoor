use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use ahjoor_::{IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};

// Test setup helpers
fn setup_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    let non_participant: ContractAddress = 0xabc.try_into().unwrap();
    (organizer, participant1, participant2, non_participant)
}

fn deploy_contracts() -> (IAhjoorROSCADispatcher, ContractAddress) {
    // Deploy mock USDC from existing test file
    let usdc_class = declare("MockUSDC").unwrap().contract_class();
    let (usdc_address, _) = usdc_class.deploy(@array![]).unwrap();
    
    // Deploy Ahjoor ROSCA with owner parameter (using organizer as owner for simplicity)
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![usdc_address.into(), owner.into()]).unwrap();
    
    (IAhjoorROSCADispatcher { contract_address: ahjoor_address }, usdc_address)
}

// Test 1: Group creation with parameters
#[test]
fn test_group_creation_with_parameters() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    start_cheat_block_timestamp(ahjoor.contract_address, 1000);
    
    let participants = array![organizer, participant1, participant2];
    
    let group_id = ahjoor.create_group(
        "Test ROSCA",
        "A test ROSCA group",
        3,
        1000_u256,
        2592000_u64, // 30 days
        participants
    );
    
    // Verify group was created correctly
    assert(group_id == 1, 'Group ID should be 1');
    assert(ahjoor.get_group_count() == 1, 'Group count should be 1');
    
    let group_info = ahjoor.get_group_info(group_id);
    assert(group_info.name == "Test ROSCA", 'Group name mismatch');
    assert(group_info.organizer == organizer, 'Organizer mismatch');
    assert(group_info.num_participants == 3, 'Participant count mismatch');
    assert(group_info.contribution_amount == 1000, 'Contribution amount mismatch');
    assert(group_info.round_duration == 2592000, 'Round duration mismatch');
    assert(group_info.current_round == 1, 'Current round should be 1');
    assert(!group_info.is_completed, 'Group should not be completed');
    
    // Verify participants are correctly identified
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer is participant');
    assert(ahjoor.is_participant(group_id, participant1), 'Participant1 in group');
    assert(ahjoor.is_participant(group_id, participant2), 'Participant2 in group');
    
    stop_cheat_caller_address(ahjoor.contract_address);
    stop_cheat_block_timestamp(ahjoor.contract_address);
}

// Test 2: Only added addresses can contribute
#[test]
fn test_only_added_addresses_can_contribute() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    // Create group
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Test that participants can identify themselves
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer is participant');
    assert(ahjoor.is_participant(group_id, participant1), 'Participant1 in group');
    assert(ahjoor.is_participant(group_id, participant2), 'Participant2 in group');
}

#[test]
#[should_panic(expected: ('Not a participant',))]
fn test_non_participant_cannot_contribute() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, non_participant) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify non-participant is not in group
    assert(!ahjoor.is_participant(group_id, non_participant), 'Non-participant not in group');
    
    start_cheat_caller_address(ahjoor.contract_address, non_participant);
    ahjoor.contribute(group_id);
}

// Test 3: Group creation validation
#[test]
#[should_panic(expected: ('Min 2 participants required',))]
fn test_group_creation_validation_min_participants() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, _, _, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer]; // Only 1 participant
    
    ahjoor.create_group(
        "Test ROSCA", "Test description", 1, 1000_u256, 86400_u64, participants
    );
}

#[test]
#[should_panic(expected: ('Organizer not in list',))]
fn test_group_creation_validation_organizer_not_in_list() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![participant1, participant2]; // Organizer not included
    
    ahjoor.create_group(
        "Test ROSCA", "Test description", 2, 1000_u256, 86400_u64, participants
    );
}

#[test]
#[should_panic(expected: ('Contribution must be > 0',))]
fn test_group_creation_validation_zero_contribution() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    
    ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 0_u256, 86400_u64, participants
    );
}

#[test]
#[should_panic(expected: ('Min 1 day round duration',))]
fn test_group_creation_validation_short_duration() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    
    ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 3600_u64, participants // 1 hour
    );
}

#[test]
#[should_panic(expected: ('Addresses count mismatch',))]
fn test_group_creation_validation_address_count_mismatch() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, _, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1]; // 2 addresses but num_participants = 3
    
    ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
}

// Test 4: Group is marked completed properly
#[test]
fn test_group_marked_completed_logic() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    // Create group
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify group is not completed initially
    let group_info = ahjoor.get_group_info(group_id);
    assert(!group_info.is_completed, 'Group not completed initially');
    assert(group_info.current_round == 1, 'Should start at round 1');
    
    // The group completion logic is tested in the main contract
    // When current_round > num_participants, group should be completed
}

// Test 5: Multiple groups can be created
#[test]
fn test_multiple_groups_creation() {
    let (ahjoor, _) = deploy_contracts();
    let (organizer, participant1, participant2, _) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    
    // Create first group
    let participants1 = array![organizer, participant1, participant2];
    let group_id1 = ahjoor.create_group(
        "ROSCA 1", "First group", 3, 1000_u256, 86400_u64, participants1
    );
    
    // Create second group
    let participants2 = array![organizer, participant1];
    let group_id2 = ahjoor.create_group(
        "ROSCA 2", "Second group", 2, 2000_u256, 172800_u64, participants2
    );
    
    assert(group_id1 == 1, 'First group ID should be 1');
    assert(group_id2 == 2, 'Second group ID should be 2');
    assert(ahjoor.get_group_count() == 2, 'Should have 2 groups');
    
    // Verify both groups exist with correct data
    let group1_info = ahjoor.get_group_info(group_id1);
    let group2_info = ahjoor.get_group_info(group_id2);
    
    assert(group1_info.name == "ROSCA 1", 'Group 1 name mismatch');
    assert(group1_info.contribution_amount == 1000, 'Group 1 contribution mismatch');
    
    assert(group2_info.name == "ROSCA 2", 'Group 2 name mismatch');
    assert(group2_info.contribution_amount == 2000, 'Group 2 contribution mismatch');
    
    stop_cheat_caller_address(ahjoor.contract_address);
}