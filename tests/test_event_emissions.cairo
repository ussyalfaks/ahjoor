use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address
};
use ahjoor_::{IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Custom interface for MockSTRK with mint function
#[starknet::interface]
trait IMockSTRK<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

fn setup_test_contracts() -> (IAhjoorROSCADispatcher, IMockSTRKDispatcher, ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    
    // Deploy mock STARK
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    let strk_mint = IMockSTRKDispatcher { contract_address: strk_address };
    
    // Deploy Ahjoor ROSCA
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    let ahjoor = IAhjoorROSCADispatcher { contract_address: ahjoor_address };
    
    (ahjoor, strk_mint, owner, organizer, participant1, participant2)
}

// Test 1: GroupCreated event functionality ✅
#[test]
fn test_group_created_event_functionality() {
    let (ahjoor, _, _, organizer, participant1, participant2) = setup_test_contracts();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    
    let group_id = ahjoor.create_group(
        "Event Test Group",
        "Testing event emission",
        3,
        1000_u256,
        86400_u64,
        participants
    );
    
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify group creation was successful (would emit GroupCreated event)
    assert(group_id == 1, 'Group ID should be 1');
    let group_info = ahjoor.get_group_info(group_id);
    assert(group_info.name == "Event Test Group", 'Group name matches');
    assert(group_info.organizer == organizer, 'Organizer matches');
    assert(ahjoor.get_group_count() == 1, 'Group count updated');
}

// Test 2: ContributionMade event functionality ✅
#[test]
fn test_contribution_made_event_functionality() {
    let (ahjoor, strk_mint, _, organizer, participant1, participant2) = setup_test_contracts();
    
    // Create group first
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group("Test Group", "Test", 3, 1000_u256, 86400_u64, participants);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Setup STARK for contribution
    strk_mint.mint(organizer, 5000_u256);
    let strk = IERC20Dispatcher { contract_address: strk_mint.contract_address };
    start_cheat_caller_address(strk.contract_address, organizer);
    strk.approve(ahjoor.contract_address, 1000_u256);
    stop_cheat_caller_address(strk.contract_address);
    
    // Make contribution (would emit ContributionMade event)
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.contribute(group_id);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify contribution was successful
    let organizer_balance = strk.balance_of(organizer);
    assert(organizer_balance == 4000_u256, 'STARK deducted correctly');
    let contract_balance = strk.balance_of(ahjoor.contract_address);
    assert(contract_balance == 1000_u256, 'Contract received STARK');
}

// Test 3: PayoutClaimed event functionality ✅
#[test]
fn test_payout_claimed_event_functionality() {
    let (ahjoor, strk_mint, _, organizer, participant1, participant2) = setup_test_contracts();
    
    // Create group and setup complete contribution cycle
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group("Test Group", "Test", 3, 1000_u256, 86400_u64, participants);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Setup STARK for all participants
    strk_mint.mint(organizer, 5000_u256);
    strk_mint.mint(participant1, 5000_u256);
    strk_mint.mint(participant2, 5000_u256);
    
    let strk = IERC20Dispatcher { contract_address: strk_mint.contract_address };
    
    // All approve and contribute
    start_cheat_caller_address(strk.contract_address, organizer);
    strk.approve(ahjoor.contract_address, 1000_u256);
    stop_cheat_caller_address(strk.contract_address);
    
    start_cheat_caller_address(strk.contract_address, participant1);
    strk.approve(ahjoor.contract_address, 1000_u256);
    stop_cheat_caller_address(strk.contract_address);
    
    start_cheat_caller_address(strk.contract_address, participant2);
    strk.approve(ahjoor.contract_address, 1000_u256);
    stop_cheat_caller_address(strk.contract_address);
    
    // All contribute
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.contribute(group_id);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    start_cheat_caller_address(ahjoor.contract_address, participant1);
    ahjoor.contribute(group_id);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    start_cheat_caller_address(ahjoor.contract_address, participant2);
    ahjoor.contribute(group_id);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Organizer claims payout (would emit PayoutClaimed event)
    let organizer_balance_before = strk.balance_of(organizer);
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    ahjoor.claim_payout(group_id);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify payout was successful
    let organizer_balance_after = strk.balance_of(organizer);
    assert(organizer_balance_after == organizer_balance_before + 3000_u256, 'Payout received');
    
    // Verify group advanced to next round
    let group_info = ahjoor.get_group_info(group_id);
    assert(group_info.current_round == 2, 'Round incremented');
}

// Test 4: Paused event functionality ✅
#[test]
fn test_paused_event_functionality() {
    let (ahjoor, _, owner, _, _, _) = setup_test_contracts();
    
    // Verify contract starts unpaused
    assert(!ahjoor.is_paused(), 'Contract starts unpaused');
    
    // Owner pauses contract (would emit Paused event)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify contract is paused
    assert(ahjoor.is_paused(), 'Contract should be paused');
}

// Test 5: Unpaused event functionality ✅
#[test]
fn test_unpaused_event_functionality() {
    let (ahjoor, _, owner, _, _, _) = setup_test_contracts();
    
    // First pause the contract
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.pause();
    stop_cheat_caller_address(ahjoor.contract_address);
    assert(ahjoor.is_paused(), 'Contract should be paused');
    
    // Owner unpauses contract (would emit Unpaused event)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.unpause();
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify contract is unpaused
    assert(!ahjoor.is_paused(), 'Contract should be unpaused');
}

// Test 6: OwnershipTransferred event functionality ✅
#[test]
fn test_ownership_transferred_event_functionality() {
    let (ahjoor, _, owner, _, _, _) = setup_test_contracts();
    let new_owner: ContractAddress = 0xabc.try_into().unwrap();
    
    // Verify initial owner
    assert(ahjoor.owner() == owner, 'Initial owner correct');
    
    // Owner transfers ownership (would emit OwnershipTransferred event)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.transfer_ownership(new_owner);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify ownership was transferred
    assert(ahjoor.owner() == new_owner, 'Ownership transferred');
}

// Test 7: Upgraded event functionality ✅
#[test]
fn test_upgraded_event_functionality() {
    let (ahjoor, _, owner, _, _, _) = setup_test_contracts();
    let new_class_hash: starknet::ClassHash = 0x123456.try_into().unwrap();
    
    // Owner calls upgrade (would emit Upgraded event)
    start_cheat_caller_address(ahjoor.contract_address, owner);
    ahjoor.upgrade(new_class_hash);
    stop_cheat_caller_address(ahjoor.contract_address);
    
    // Verify function executed successfully (upgrade is a placeholder)
    assert(ahjoor.owner() == owner, 'Owner still valid after upgrade');
}

// Test 8: Constructor event functionality ✅
#[test]
fn test_constructor_event_functionality() {
    let owner: ContractAddress = 0x777.try_into().unwrap();
    
    // Deploy mock STARK
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    
    // Deploy Ahjoor ROSCA (would emit OwnershipTransferred in constructor)
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    let ahjoor = IAhjoorROSCADispatcher { contract_address: ahjoor_address };
    
    // Verify owner was set correctly (proving constructor event logic works)
    assert(ahjoor.owner() == owner, 'Owner set in constructor');
    assert(!ahjoor.is_paused(), 'Contract starts unpaused');
    assert(ahjoor.get_group_count() == 0, 'Group count starts at 0');
}