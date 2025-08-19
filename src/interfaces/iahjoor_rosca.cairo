use starknet::ContractAddress;
use crate::structs::group_info::GroupInfo;

/// Ahjoor ROSCA Interface
#[starknet::interface]
pub trait IAhjoorROSCA<TContractState> {
    fn create_group(
        ref self: TContractState,
        name: ByteArray,
        description: ByteArray,
        num_participants: u32,
        contribution_amount: u256,
        round_duration: u64,
        participant_addresses: Array<ContractAddress>
    ) -> u256;
    
    fn contribute(ref self: TContractState, group_id: u256);
    fn claim_payout(ref self: TContractState, group_id: u256);
    fn get_group_info(self: @TContractState, group_id: u256) -> GroupInfo;
    fn is_participant(self: @TContractState, group_id: u256, address: ContractAddress) -> bool;
    fn get_group_count(self: @TContractState) -> u256;
    
    // Admin functions (OpenZeppelin style)
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
    fn upgrade(ref self: TContractState, new_class_hash: starknet::ClassHash);
    
    // View functions
    fn is_paused(self: @TContractState) -> bool;
    fn owner(self: @TContractState) -> ContractAddress;
}