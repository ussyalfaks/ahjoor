use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use ahjoor_::{IAhjoorROSCADispatcher, IAhjoorROSCADispatcherTrait};

// Mock STARK for testing
#[starknet::contract]
mod MockSTRK {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[starknet::interface]
    trait IERC20<TContractState> {
        fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
        fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
        fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
        fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
        fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);
            assert(caller_balance >= amount, 'Insufficient balance');
            
            self.balances.write(caller, caller_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            true
        }

        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((sender, caller));
            assert(allowance >= amount, 'Insufficient allowance');
            
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, 'Insufficient balance');
            
            self.allowances.write((sender, caller), allowance - amount);
            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            true
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            true
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            let balance = self.balances.read(to);
            self.balances.write(to, balance + amount);
        }
    }
}

fn deploy_contracts() -> (IAhjoorROSCADispatcher, ContractAddress) {
    // Deploy mock STARK
    let strk_class = declare("MockSTRK").unwrap().contract_class();
    let (strk_address, _) = strk_class.deploy(@array![]).unwrap();
    
    // Deploy Ahjoor ROSCA with owner parameter
    let owner: ContractAddress = 0x999.try_into().unwrap();
    let ahjoor_class = declare("AhjoorROSCA").unwrap().contract_class();
    let (ahjoor_address, _) = ahjoor_class.deploy(@array![strk_address.into(), owner.into()]).unwrap();
    
    (IAhjoorROSCADispatcher { contract_address: ahjoor_address }, strk_address)
}

#[test]
fn test_create_group() {
    let (ahjoor, _) = deploy_contracts();
    let organizer: ContractAddress = 0x123.try_into().unwrap();
    
    start_cheat_caller_address(ahjoor.contract_address, organizer);
    
    let participants = array![
        organizer,
        0x456.try_into().unwrap(),
        0x789.try_into().unwrap()
    ];
    
    let group_id = ahjoor.create_group(
        "Test Group",
        "A test ROSCA group",
        3,
        1000_u256,
        86400_u64,
        participants
    );
    
    assert(group_id == 1, 'Group ID should be 1');
    assert(ahjoor.get_group_count() == 1, 'Group count should be 1');
    assert(ahjoor.is_participant(group_id, organizer), 'Organizer should be participant');
    
    stop_cheat_caller_address(ahjoor.contract_address);
}