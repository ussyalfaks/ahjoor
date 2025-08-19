use starknet::ContractAddress;

/// Events for ROSCA contract
#[derive(Drop, starknet::Event)]
pub struct GroupCreated {
    #[key]
    pub group_id: u256,
    pub organizer: ContractAddress,
    pub name: ByteArray,
    pub num_participants: u32,
    pub contribution_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct ContributionMade {
    #[key]
    pub group_id: u256,
    #[key]
    pub participant: ContractAddress,
    pub amount: u256,
    pub round: u32,
}

#[derive(Drop, starknet::Event)]
pub struct PayoutClaimed {
    #[key]
    pub group_id: u256,
    #[key]
    pub recipient: ContractAddress,
    pub amount: u256,
    pub round: u32,
}

#[derive(Drop, starknet::Event)]
pub struct Paused {
    pub account: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Unpaused {
    pub account: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct OwnershipTransferred {
    #[key]
    pub previous_owner: ContractAddress,
    #[key]
    pub new_owner: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Upgraded {
    pub new_class_hash: starknet::ClassHash,
}