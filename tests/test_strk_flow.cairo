use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address
};
use ahjoor_::{IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};

// Simple test to verify STARK contribution flow compiles and basic logic works
#[test]
fn test_strk_contribution_basic_flow() {
    // Deploy contracts
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    
    // Deploy mock STARK
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    
    // Deploy Ahjoor ROSCA
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    let ahjoor = IAhjoorROSCADispatcher { contract_address: ahjoor_address };
    
    // Create a group
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "STARK Test Group",
        "Testing STARK integration",
        3,
        1000_u256,
        86400_u64,
        participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify group was created successfully
    assert(group_id == 1, 'Group should be created');
    let group_info = ahjoor.get_group_info(group_id);
    assert(group_info.contribution_amount == 1000, 'Contribution amount set');
    assert(group_info.num_participants == 3, 'Three participants set');
    
    // Verify participants are correctly identified
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer is participant');
    assert(ahjoor.is_participant(group_id, participant1), 'Participant1 in group');
    assert(ahjoor.is_participant(group_id, participant2), 'Participant2 in group');
}

// Test that contribution fails without proper STARK setup
#[test]
#[should_panic(expected: ('Insufficient allowance',))]
fn test_contribution_fails_without_strk() {
    // Deploy contracts
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    
    // Deploy mock STARK
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    
    // Deploy Ahjoor ROSCA
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    let ahjoor = IAhjoorROSCADispatcher { contract_address: ahjoor_address };
    
    // Create a group
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Test Group", "Test", 3, 1000_u256, 86400_u64, participants
    );
    
    // Try to contribute without STARK balance/approval - should fail
    ahjoor.contribute(group_id);
}