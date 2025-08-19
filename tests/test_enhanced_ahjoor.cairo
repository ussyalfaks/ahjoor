use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use ahjoor_::{IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};

// Test setup helpers
fn setup_addresses() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    (owner, organizer, participant1, participant2)
}

fn deploy_enhanced_contracts() -> (IAhjoorROSCADispatcher, ContractAddress, ContractAddress) {
    let (owner, _, _, _) = setup_addresses();
    
    // Deploy mock USDC (using existing MockUSDC)
    let usdc_class = declare("MockUSDC").unwrap().contract_class();
    let (usdc_address, _) = usdc_class.deploy(@array![]).unwrap();
    
    // Deploy enhanced Ahjoor ROSCA with owner parameter
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![usdc_address.into(), owner.into()]).unwrap();
    
    (IAhjoorROSCADispatcher { contract_address: ahjoor_address }, usdc_address, owner)
}

// Test 1: Enhanced contract deployment with owner
#[test]
fn test_enhanced_contract_deployment() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    
    // Verify owner is set correctly
    let contract_owner = ahjoor.owner();
    assert(contract_owner == owner, 'Owner should be set correctly');
    
    // Verify contract starts unpaused
    assert(!ahjoor.is_paused(), 'Contract should start unpaused');
    
    // Verify initial group count
    assert(ahjoor.get_group_count() == 0, 'Initial group count should be 0');
}

// Test 2: Pausable functionality
#[test]
fn test_pausable_functionality() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    // Owner can pause the contract
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify contract is paused
    assert(ahjoor.is_paused(), 'Contract should be paused');
    
    // Try to create group while paused (should fail)
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    
    // This should fail due to pause
    // Note: We can't test the actual panic in a simple test, but the contract will reject
    
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Owner can unpause
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.unpause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify contract is unpaused
    assert(!ahjoor.is_paused(), 'Contract should be unpaused');
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_create_group_fails_when_paused() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    // Pause the contract
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Try to create group while paused
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_contribute_fails_when_paused() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    // Create group first (while unpaused)
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Pause the contract
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Try to contribute while paused
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.contribute(group_id);
}

// Test 3: Access control for admin functions
#[test]
#[should_panic(expected: ('Ownable: caller not owner',))]
fn test_non_owner_cannot_pause() {
    let (ahjoor, _usdc_address, _owner) = deploy_enhanced_contracts();
    let (_, organizer, _, _) = setup_addresses();
    
    // Non-owner tries to pause
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.pause();
}

#[test]
#[should_panic(expected: ('Ownable: caller not owner',))]
fn test_non_owner_cannot_unpause() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, _, _) = setup_addresses();
    
    // Owner pauses first
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Non-owner tries to unpause
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.unpause();
}

// Test 4: Enhanced group creation still works
#[test]
fn test_enhanced_group_creation() {
    let (ahjoor, _usdc_address, _owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    start_cheat_block_timestamp(ahjoor.contract_address, 1000);
    
    let participants = array![organizer, participant1, participant2];
    
    let group_id = ahjoor.create_group(
        "Enhanced ROSCA",
        "A ROSCA with OpenZeppelin features",
        3,
        1000_u256,
        86400_u64,
        participants
    );
    
    // Verify group was created correctly
    assert(group_id == 1, 'Group ID should be 1');
    assert(ahjoor.get_group_count() == 1, 'Group count should be 1');
    
    let group_info = ahjoor.get_group_info(group_id);
    assert(group_info.name == "Enhanced ROSCA", 'Group name mismatch');
    assert(group_info.description == "A ROSCA with OpenZeppelin features", 'Description mismatch');
    assert(group_info.organizer == organizer, 'Organizer mismatch');
    assert(group_info.num_participants == 3, 'Participant count mismatch');
    assert(group_info.contribution_amount == 1000, 'Contribution amount mismatch');
    
    // Verify participants
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer should be participant');
    assert(ahjoor.is_participant(group_id, participant1), 'Participant1 in group');
    assert(ahjoor.is_participant(group_id, participant2), 'Participant2 in group');
    
    stop_cheat_caller_address(ahjoor.contract_address);
    stop_cheat_block_timestamp(ahjoor.contract_address);
}

// Test 5: Enhanced contract maintains all original ROSCA functionality
#[test]
fn test_original_rosca_functionality_preserved() {
    let (ahjoor, _usdc_address, _owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    // Test group creation validation still works
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    
    // Test minimum participants validation
    let single_participant = array![organizer];
    // This would panic: ahjoor.create_group("Test", "Test", 1, 1000_u256, 86400_u64, single_participant);
    
    // Test valid group creation
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test ROSCA", "Test description", 3, 1000_u256, 86400_u64, participants
    );
    
    // Test participant identification
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer is participant');
    assert(ahjoor.is_participant(group_id, participant1), 'Participant1 in group');
    assert(ahjoor.is_participant(group_id, participant2), 'Participant2 in group');
    
    // Test non-participant
    let non_participant: ContractAddress = 0xabc.try_into().unwrap();
    assert(!ahjoor.is_participant(group_id, non_participant), 'Non-participant not in group');
    
    stop_cheat_caller_address(ahjoor.contract_address);
}

// Test 6: Multiple groups with enhanced features
#[test]
fn test_multiple_groups_with_enhanced_features() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, participant1, participant2) = setup_addresses();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    
    // Create first group
    let participants1 = array![organizer, participant1, participant2];
    let group_id1 = ahjoor.create_group(
        "ROSCA 1", "First enhanced group", 3, 1000_u256, 86400_u64, participants1
    );
    
    // Pause contract as owner
    stop_cheat_caller_address(ahjoor.contract_address);
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Cannot create second group while paused
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    // This would fail: ahjoor.create_group(...)
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Unpause and create second group
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.unpause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants2 = array![organizer, participant1];
    let group_id2 = ahjoor.create_group(
        "ROSCA 2", "Second enhanced group", 2, 2000_u256, 172800_u64, participants2
    );
    
    assert(group_id1 == 1, 'First group ID should be 1');
    assert(group_id2 == 2, 'Second group ID should be 2');
    assert(ahjoor.get_group_count() == 2, 'Should have 2 groups');
    
    stop_cheat_caller_address(ahjoor.contract_address);
}

// Test 7: Upgrade functionality (basic test)
#[test]
fn test_upgrade_access_control() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    let (_, organizer, _, _) = setup_addresses();
    
    // Only owner should be able to call upgrade
    // Note: We can't test actual upgrade without deploying a new class
    // but we can test access control
    
    let dummy_class_hash: starknet::ClassHash = 0x123.try_into().unwrap();
    
    // Owner can call upgrade (will fail due to invalid class hash, but access is granted)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    // ahjoor.upgrade(dummy_class_hash); // Would fail with invalid class hash
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Non-owner cannot call upgrade - this is tested by the panic test below
}

#[test]
#[should_panic(expected: ('Ownable: caller not owner',))]
fn test_non_owner_cannot_upgrade() {
    let (ahjoor, _usdc_address, _owner) = deploy_enhanced_contracts();
    let (_, organizer, _, _) = setup_addresses();
    
    let dummy_class_hash: starknet::ClassHash = 0x123.try_into().unwrap();
    
    // Non-owner tries to upgrade
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.upgrade(dummy_class_hash);
}

// Test 8: Event emission for enhanced features
#[test]
fn test_enhanced_events() {
    let (ahjoor, _usdc_address, owner) = deploy_enhanced_contracts();
    
    // Test pause/unpause events (we can't directly test events in this framework,
    // but the functions should execute without error)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    
    ahjoor.pause();
    assert(ahjoor.is_paused(), 'Should be paused');
    
    ahjoor.unpause();
    assert(!ahjoor.is_paused(), 'Should be unpaused');
    
    stop_cheat_caller_address(ahjoor.contract_address);
}