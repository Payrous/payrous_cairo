/// Interface representing `HelloContract`.
/// This interface allows modification and retrieval of the contract balance.
/// 
use starknet::ContractAddress;
use payrous_starknet::types::{UserDetails, OrganizationDetails};
use core::array::ArrayTrait;
use core::starknet::storage;

#[starknet::interface]
pub trait IPyarous<TContractState> {
    // Write functions
    fn initialize(ref self: TContractState, organization_name: felt252, token_address: ContractAddress, owner: ContractAddress, platform_fee_recipient: ContractAddress);
    fn add_multiple_employees(ref self: TContractState, employees: Array<ContractAddress>, amounts: Array<u256>);
    fn add_employee(ref self: TContractState, employee: ContractAddress, amount: u256);
    fn remove_employee(ref self: TContractState, employee: ContractAddress);
    fn send_to_employee(ref self: TContractState);
    fn public_send(ref self: TContractState, recipients: Array<ContractAddress>, amounts: Array<u256>, token_address: ContractAddress);
    fn deposit(ref self: TContractState, amount: u256);
    fn update_payment_token(ref self: TContractState, token_address: ContractAddress); 
    fn withdraw_locked_funds(ref self: TContractState, token_address: ContractAddress);
    fn update_platform_fee(ref self: TContractState, platform_fee: u256);
    fn transfer_native_funds(ref self: TContractState);

    // view functions
    fn get_organization_details(self: @TContractState) -> OrganizationDetails;
    fn get_employee_details(self: @TContractState, employee: ContractAddress) -> (u256, u256, u256);
    fn get_all_employee_address(self: @TContractState) -> Array<ContractAddress>;
    fn get_employee_count(self: @TContractState) -> u256;
    fn get_employee_balance(self: @TContractState, employee: ContractAddress) -> u256;
    fn get_contract_balance(self: @TContractState) -> u256;
}


#[starknet::contract]
mod Payrous {
    use super::IPyarous;
use core::array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};  
    use payrous_starknet::errors;
    use core::num::traits::Zero;


    #[storage]
    struct Storage {
        owner: ContractAddress,
        platform_fee_recipient: ContractAddress,
        last_index: u256,
        max_employees: u256,
        platform_fee: u256,
        initialized: bool,
        organizationDetails: OrganizationDetails,
        employeeIndex: Map<ContractAddress, u256>,
        employeeExists: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC20Transfer: ERC20Transfer,
        NativeTransfer: NativeTransfer,
    }

    #[derive(Drop, starknet::Event)]
    struct ERC20Transfer {
        #[key]
        owner: ContractAddress,
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        amount: u256,
    }  

    #[derive(Drop, starknet::Event)]
    struct NativeTransfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        qmount: u256
    }  


    #[abi(embed_v0)]
    impl PayrousImpl of super::IPyarous<ContractState> {

        fn initialize(ref self: ContractState, organization_name: felt252, token_address: ContractAddress, owner: ContractAddress, platform_fee_recipient: ContractAddress) {


            // if (initialized) {
            //     revert AlreadyInitialized();
            // }
    
            // if(_tokenAddress == address(0)){
            //     revert InvalidAddress();
            // }
            // owner = _owner;
            // organizationDetails.organizationName = _organizationName;
            // organizationDetails.organizationAddress = _owner;
            // organizationDetails.tokenAddress = _tokenAddress;
            // platformFeeRecipient = _platformFeeRecipient;
            // MAX_EMPLOYEES = 1500;
            // PLATFORM_FEE = 5;
    
            // initialized = true;

            assert(self.initialized.read() == false, errors::ALREADY_INITIALIZED);
            assert(!token_address.is_zero(), errors::INVALID_ADDRESS);

            self.owner.write(owner);



       

        }




        // fn increase_balance(ref self: ContractState, amount: felt252) {
        //     assert(amount != 0, 'Amount cannot be 0');
        //     self.balance.write(self.balance.read() + amount);
        // }

        // fn get_balance(self: @ContractState) -> felt252 {
        //     self.balance.read()
        // }
    }
}
