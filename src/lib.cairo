/// Ahjoor ROSCA Smart Contract
/// Rotating Savings and Credit Association (ROSCA) implementation
/// Built with OpenZeppelin patterns for Starknet

pub mod interfaces {
    pub mod iahjoor_rosca;
}

pub mod contracts {
    pub mod ahjoor_rosca;
    pub mod mock_usdc;
}

pub mod structs {
    pub mod group_info;
}

pub mod events {
    pub mod ahjoor_events;
}

// Re-export main interface and dispatcher for easy access
pub use interfaces::iahjoor_rosca::{IAhjoorROSCA, IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};