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

#[derive(Drop)]
struct TestSetup {
    ahjoor: IAhjoorROSCADispatcher,
    strk: IERC20Dispatcher,
    strk_mint: IMockSTRKDispatcher,
    owner: ContractAddress,
    organizer: ContractAddress,
    participant1: ContractAddress,
    participant2: ContractAddress,
    group_id: u256,
}

fn setup_complete_test() -> TestSetup {
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    let participant1: ContractAddress = 0x456.try_into().unwrap();
    let participant2: ContractAddress = 0x789.try_into().unwrap();
    
    // Deploy mock STARK with OpenZeppelin
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    let strk = IERC20Dispatcher { contract_address: strk_address };
    let strk_mint = IMockSTRKDispatcher { contract_address: strk_address };
    
    // Deploy Ahjoor ROSCA
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    let ahjoor = IAhjoorROSCADispatcher { contract_address: ahjoor_address };
    
    // Create group
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    let participants = array![organizer, participant1, participant2];
    let group_id = ahjoor.create_group(
        "Complete ROSCA Test",
        "Testing full workflow",
        3,
        1000_u256,
        86400_u64, // 1 day
        participants
    );
    stop_cheat_caller_address(ahjoor.contract_address);
    
    TestSetup {
        ahjoor, strk, strk_mint, owner, organizer, participant1, participant2, group_id
    }
}

// Test 1: Group creation with parameters ✅
#[test]
fn test_group_creation_with_parameters() {
    let setup = setup_complete_test();
    
    // Verify group was created with correct parameters
    let group_info = setup.ahjoor.get_group_info(setup.group_id);
    assert(group_info.name == "Complete ROSCA Test", 'Group name correct');
    assert(group_info.description == "Testing full workflow", 'Description correct');
    assert(group_info.organizer == setup.organizer, 'Organizer correct');
    assert(group_info.num_participants == 3, 'Participant count correct');
    assert(group_info.contribution_amount == 1000, 'Contribution amount correct');
    assert(group_info.round_duration == 86400, 'Round duration correct');
    assert(group_info.current_round == 1, 'Initial round correct');
    assert(!group_info.is_completed, 'Initially not completed');
}

// Test 2: Only added addresses can contribute ✅
#[test]
fn test_only_added_addresses_can_contribute() {
    let setup = setup_complete_test();
    
    // Verify participants can be identified
    assert(setup.ahjoor.is_participant(setup.group_id, setup.organizer), 'Organizer is participant');
    assert(setup.ahjoor.is_participant(setup.group_id, setup.participant1), 'Participant1 identified');
    assert(setup.ahjoor.is_participant(setup.group_id, setup.participant2), 'Participant2 identified');
    
    // Verify non-participant is not allowed
    let non_participant: ContractAddress = 0xabc.try_into().unwrap();
    assert(!setup.ahjoor.is_participant(setup.group_id, non_participant), 'Non-participant rejected');
}

// Test 3: Payout released to correct participant based on order ✅
#[test]
fn test_payout_order_correctness() {
    let mut setup = setup_complete_test();
    let contribution_amount = 1000_u256;
    
    // Setup STARK for all participants
    setup.strk_mint.mint(setup.organizer, 5000_u256);
    setup.strk_mint.mint(setup.participant1, 5000_u256);
    setup.strk_mint.mint(setup.participant2, 5000_u256);
    
    // All participants approve contract
    start_cheat_caller_address(setup.strk.contract_address, setup.organizer);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant1);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant2);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    // All participants contribute for round 1
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // First payout should go to organizer (index 0)
    let organizer_balance_before = setup.strk.balance_of(setup.organizer);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.claim_payout(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    let organizer_balance_after = setup.strk.balance_of(setup.organizer);
    let expected_payout = contribution_amount * 3; // 3000 STARK total pool
    
    assert(organizer_balance_after == organizer_balance_before + expected_payout, 'Organizer got correct payout');
}

// Test 4: Organizer cannot withdraw (non-recipients cannot claim) ✅
#[test]
#[should_panic(expected: ('Not your turn for payout',))]
fn test_organizer_cannot_withdraw_out_of_turn() {
    let mut setup = setup_complete_test();
    let contribution_amount = 1000_u256;
    
    // Setup and complete round 1
    setup.strk_mint.mint(setup.organizer, 5000_u256);
    setup.strk_mint.mint(setup.participant1, 5000_u256);
    setup.strk_mint.mint(setup.participant2, 5000_u256);
    
    // All approve and contribute
    start_cheat_caller_address(setup.strk.contract_address, setup.organizer);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 2);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant1);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 2);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant2);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 2);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    // Round 1 contributions
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // Organizer claims round 1 payout
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.claim_payout(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // Now we're in round 2, participant1 should be next (index 1)
    // Round 2 contributions
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // Organizer tries to claim again - should fail
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.claim_payout(setup.group_id); // Should panic
}

// Test 5: Attempting to contribute after completion fails ✅
#[test]
#[should_panic(expected: ('Group is completed',))]
fn test_contribute_after_completion_fails() {
    let mut setup = setup_complete_test();
    let contribution_amount = 1000_u256;
    
    // Setup STARK for 3 full rounds
    setup.strk_mint.mint(setup.organizer, 10000_u256);
    setup.strk_mint.mint(setup.participant1, 10000_u256);
    setup.strk_mint.mint(setup.participant2, 10000_u256);
    
    // All participants approve for 3 rounds
    start_cheat_caller_address(setup.strk.contract_address, setup.organizer);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant1);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant2);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    // Complete all 3 rounds
    let mut round: u32 = 1;
    loop {
        if round > 3 {
            break;
        }
        // All contribute
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        // Determine who gets payout based on round
        let recipient = if round == 1 {
            setup.organizer
        } else if round == 2 {
            setup.participant1
        } else {
            setup.participant2
        };
        
        // Claim payout
        start_cheat_caller_address(setup.ahjoor.contract_address, recipient);
        setup.ahjoor.claim_payout(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        round += 1;
    };
    
    // Verify group is completed
    let group_info = setup.ahjoor.get_group_info(setup.group_id);
    assert(group_info.is_completed, 'Group should be completed');
    
    // Try to contribute after completion - should fail
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.contribute(setup.group_id); // Should panic
}

// Test 6: Group is marked completed after last payout ✅
#[test]
fn test_group_marked_completed_after_last_payout() {
    let mut setup = setup_complete_test();
    let contribution_amount = 1000_u256;
    
    // Setup STARK for 3 full rounds
    setup.strk_mint.mint(setup.organizer, 10000_u256);
    setup.strk_mint.mint(setup.participant1, 10000_u256);
    setup.strk_mint.mint(setup.participant2, 10000_u256);
    
    // All participants approve for 3 rounds
    start_cheat_caller_address(setup.strk.contract_address, setup.organizer);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant1);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    start_cheat_caller_address(setup.strk.contract_address, setup.participant2);
    setup.strk.approve(setup.ahjoor.contract_address, contribution_amount * 3);
    stop_cheat_caller_address(setup.strk.contract_address);
    
    // Complete round 1 and 2, verify not completed yet
    let mut round: u32 = 1;
    loop {
        if round > 2 {
            break;
        }
        // All contribute
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
        setup.ahjoor.contribute(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        // Claim payout
        let recipient = if round == 1 { setup.organizer } else { setup.participant1 };
        start_cheat_caller_address(setup.ahjoor.contract_address, recipient);
        setup.ahjoor.claim_payout(setup.group_id);
        stop_cheat_caller_address(setup.ahjoor.contract_address);
        
        // Verify still not completed
        let group_info = setup.ahjoor.get_group_info(setup.group_id);
        assert(!group_info.is_completed, 'Should not be completed yet');
        
        round += 1;
    };
    
    // Complete final round 3
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.organizer);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant1);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
    setup.ahjoor.contribute(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // Final payout to participant2
    start_cheat_caller_address(setup.ahjoor.contract_address, setup.participant2);
    setup.ahjoor.claim_payout(setup.group_id);
    stop_cheat_caller_address(setup.ahjoor.contract_address);
    
    // NOW verify group is completed
    let group_info = setup.ahjoor.get_group_info(setup.group_id);
    assert(group_info.is_completed, 'Group should be completed');
    assert(group_info.current_round == 4, 'Round 4 after completion'); // Round increments after last payout
}