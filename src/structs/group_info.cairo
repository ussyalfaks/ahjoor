use starknet::ContractAddress;

/// Group Information Structure
#[derive(Drop, Serde, starknet::Store)]
pub struct GroupInfo {
    pub name: ByteArray,
    pub description: ByteArray,
    pub organizer: ContractAddress,
    pub num_participants: u32,
    pub contribution_amount: u256,
    pub round_duration: u64,
    pub num_participants_stored: u32,
    pub current_round: u32,
    pub is_completed: bool,
    pub created_at: u64,
    pub last_payout_time: u64,
}