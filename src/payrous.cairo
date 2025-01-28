/// Interface representing `HelloContract`.
/// This interface allows modification and retrieval of the contract balance.
/// 
use starknet::ContractAddress;
use core::starknet::storage;
use payrous_starknet::types::OrganizationDetails;


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

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn initialize(ref self: TContractState,name: ByteArray, symbol: ByteArray, initial_supply: u256);
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256);
    fn transfer_from( ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    

}


#[starknet::contract]
mod Payrous {
    use super::IPyarous;
    use core::array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};  
    use starknet::storage::{StorageBase, FlattenedStorage, StorageTrait, StorageTraitMut};
    use starknet::storage::StoragePointer;
    use payrous_starknet::errors;
    use core::num::traits::Zero;
    use payrous_starknet::types::OrganizationDetails;
    use starknet::{get_caller_address, get_contract_address, contract_address_const, get_block_timestamp};


    #[storage]
    struct Storage {
        owner: ContractAddress,
        platform_fee_recipient: ContractAddress,
        last_index: u32,
        max_employees: u32,
        platform_fee: u256,
        initialized: bool,
        organizationDetails: OrganizationDetails,
        organization_employees: Map<u32, ContractAddress>,
        employee_amounts: Map<u32, u256>,
        employeeIndex: Map<ContractAddress, u32>,
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
        token_address: ContractAddress,
        #[key]
        sender: ContractAddress,
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
        amount: u256
    }  


    #[abi(embed_v0)]
    impl PayrousImpl of super::IPyarous<ContractState> {

        fn initialize(ref self: ContractState, organization_name: felt252, token_address: ContractAddress, owner: ContractAddress, platform_fee_recipient: ContractAddress) {

            assert(self.initialized.read() == false, errors::ALREADY_INITIALIZED);
            assert(!token_address.is_zero(), errors::INVALID_ADDRESS);
            self.platform_fee_recipient.write(platform_fee_recipient);
            
            self.max_employees.write(1500);
            self.platform_fee.write(5);
            self.owner.write(owner);

            let _organizationDetails = OrganizationDetails {
                organization_name: organization_name,
                organization_address: owner,
                token_address: token_address,
                employees_length: 0, 
                amount_to_be_paid_length: 0,
                payment_interval: 0,
                start_time: 0,
                end_time: 0,
                is_payment_active: false
            };

            self.organizationDetails.write(_organizationDetails);

            self.initialized.write(true);
        }


        fn add_multiple_employees(ref self: ContractState, employees: Array<ContractAddress>, amounts: Array<u256>) {
            assert(employees.len() == amounts.len(), errors::INVALID_LENGTH);
            assert(employees.len() <= self.max_employees.read(), errors::MAX_EMPLOYEE);
        
            let mut index: u32 = 0;
            let len = employees.len();
            let mut current_details = self.organizationDetails.read();
        
            while index < len {
                // Check if address is valid and doesn't already exist
                if(employees[index].is_zero() || self.employeeExists.entry(*employees[index]).read()) {
                    assert(false, errors::INVALID_ADDRESS);
                }
        
                // // Add employee to organization details
                // current_details.employees.append(*employees[index]);
                // current_details.amount_to_be_paid.append(*amounts[index]);
                current_details.employees_length += 1;
        
                // Update employee mappings
                let current_index = self.last_index.read();
                self.employeeIndex.write(*employees[index], current_index);
                self.employeeExists.write(*employees[index], true);
        
                // Update the state mappings
                self.organization_employees.entry(current_index).write(*employees[index]);
                self.employee_amounts.entry(current_index).write(*amounts[index]);
        
                self.last_index.write(current_index + 1);
                index += 1;
            };
        
            self.organizationDetails.write(current_details);
        }


        fn add_employee(ref self: ContractState, employee: ContractAddress, amount: u256) {
            assert(!employee.is_zero(), errors::INVALID_ADDRESS);
            assert(amount != 0, errors::INVALID_AMOUNT);
            assert(self.employeeExists.entry(employee).read() == false, errors::EMPLOYEE_ALREADY_EXIST);
            assert(self.organizationDetails.read().employees_length < self.max_employees.read(), errors::MAX_EMPLOYEE);
        
            let mut current_details = self.organizationDetails.read();

            current_details.employees_length += 1;
        
            // Update employee mappings
            let current_index = self.last_index.read();
            self.employeeIndex.write(employee, current_index);
            self.employeeExists.write(employee, true);
        
            // Update the state mappings
            self.organization_employees.entry(current_index).write(employee);
            self.employee_amounts.entry(current_index).write(amount);
        
            self.last_index.write(current_index + 1);
        
            self.organizationDetails.write(current_details);
        }


        fn remove_employee(ref self: ContractState, employee: ContractAddress) {
            assert(!employee.is_zero(), errors::INVALID_ADDRESS);
            assert(self.employeeExists.entry(employee).read(), errors::EMPLOYEE_NOT_FOUND);
        
            let mut current_details = self.organizationDetails.read();
            let employee_index = self.employeeIndex.entry(employee).read();
        
            // Remove employee from organization details
            current_details.employees_length -= 1;
        
            // Update employee mappings
            self.employeeExists.write(employee, false);
            self.employeeIndex.write(employee, 0); // Reset the index
        
            // write zero/default values
            // self.organization_employees.write(employee_index, ContractAddress::from(0));
            // self.employee_amounts.write(employee_index, 0);
        
            let mut i = employee_index;
            while i < current_details.employees_length.into() {
                let next_index = i + 1;
                let next_employee = self.organization_employees.read(next_index);
                let next_amount = self.employee_amounts.read(next_index);
                
                self.organization_employees.write(i, next_employee);
                self.employee_amounts.write(i, next_amount);
                
                i += 1;
            };
        
            // Clear the last position after shifting
            self.organization_employees.write(current_details.employees_length.into(), Zero::zero());
            self.employee_amounts.write(current_details.employees_length.into(), 0);
        
            self.organizationDetails.write(current_details);
        }


        fn send_to_employee(ref self: ContractState) {
            let current_details = self.organizationDetails.read();
            
            // Check end time if it's set
            if current_details.end_time != 0 {
                assert(get_block_timestamp() < current_details.end_time, errors::INVALID_TIME);
            }

            // Check start time and update interval
            assert(get_block_timestamp() >= current_details.start_time, errors::UNAUTHORIZED);
            
            let mut updated_details = current_details;
            updated_details.start_time += current_details.payment_interval;
            updated_details.is_payment_active = true;
            
            // Check if there are employees
            assert(current_details.employees_length > 0, errors::EMPLOYEE_NOT_FOUND);

            // Handle native token (ETH) transfers
            if current_details.token_address == get_contract_address() {
                let mut i: u32 = 0;
                while i < current_details.employees_length {
                    let recipient = self.organization_employees.read(i);
                    let amount = self.employee_amounts.read(i);
                    
                    // Transfer native tokens
                    send_eth_transfer(recipient, amount);
                    
                    // Emit event
                    self.emit(NativeTransfer { from: get_caller_address(), to: recipient, amount: amount });
                    i += 1;
                }
            } else {
                // Handle ERC20 transfers
                let mut i: u32 = 0;
                while i < current_details.employees_length {
                    let recipient = self.organization_employees.read(i);
                    let amount = self.employee_amounts.read(i);
                    
                    // Create ERC20 dispatcher
                    let token = IERC20Dispatcher{
                        contract_address: current_details.token_address
                    };
                    
                    // Transfer ERC20 tokens
                    token.transfer(recipient, amount);
                    
                    // Emit event
                    self.emit(ERC20Transfer { token_address: current_details.token_address, sender: get_caller_address(), to: recipient, amount: amount });  
                    i += 1;
                };
            }
            // Update organization details
            self.organizationDetails.write(updated_details);
        }

        fn public_send(
            ref self: ContractState,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>,
            token_address: ContractAddress
        ) {
            // Check lengths match
            assert(recipients.len() == amounts.len(), errors::INVALID_LENGTH);

            // Calculate total amount and platform fee
            let mut total_amount: u256 = 0;
            let mut i: u32 = 0;
            while i < amounts.len() {
                total_amount += *amounts[i];
                i += 1;
            };

            let platform_fee = (total_amount * self.platform_fee.read()) / 100;
            assert(platform_fee > 0, errors::INVALID_PLATFORM_FEES);

            // Handle native token transfers
            if token_address == get_contract_address() {
                // Check sufficient balance was sent
                let required_amount = total_amount + platform_fee;
                let sent_value = get_txn_value();
                assert(sent_value >= required_amount, errors::INSUFFICIENT_BALANCE);

                // Transfer platform fee
                let fee_recipient = self.platform_fee_recipient.read();
                send_eth_transfer(fee_recipient, platform_fee);
                
                self.emit(NativeTransfer { from: get_caller_address(), to: fee_recipient, amount: platform_fee});

                // Transfer to recipients
                let mut j: u32 = 0;
                while j < recipients.len() {
                    let recipient = *recipients[j];
                    let amount = *amounts[j];
                    
                    send_eth_transfer(recipient, amount);
                    
                    self.emit(NativeTransfer {from: get_caller_address(), to: recipient, amount: amount});
                    j += 1;
                };

                // Handle excess refund
                let excess = sent_value - required_amount;
                if excess > 0 {
                    send_eth_transfer(get_caller_address(), excess);
                }
            } else {
                // Handle ERC20 transfers
                let token = IERC20Dispatcher { contract_address: token_address };
                let caller = get_caller_address();
                let fee_recipient = self.platform_fee_recipient.read();

                // Transfer platform fee
                token.transfer_from(caller, fee_recipient, platform_fee);
                
                self.emit(ERC20Transfer { token_address, sender: caller, to: fee_recipient, amount: platform_fee });

                // Transfer to recipients
                let mut k: u32 = 0;
                while k < recipients.len() {
                    let recipient = *recipients[k];
                    let amount = *amounts[k];
                    
                    token.transfer_from(caller, recipient, amount);
                    
                    self.emit(ERC20Transfer {token_address, sender: caller, to: recipient, amount });
                    k += 1;
                }
            }
        }


        // fn d






  
  





        // fn increase_balance(ref self: ContractState, amount: felt252) {
        //     assert(amount != 0, 'Amount cannot be 0');
        //     self.balance.write(self.balance.read() + amount);
        // }

        // fn get_balance(self: @ContractState) -> felt252 {
        //     self.balance.read()
        // }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        // Helper function for ETH transfer
        fn send_eth_transfer(to: ContractAddress, amount: u256) {
            let transfer_syscall = starknet::syscalls::send_message_to_l1_syscall(
                to,
                array![amount.try_into().unwrap()].span()
            );
            assert(transfer_syscall.is_ok(), 'ETH transfer failed');
        }


    }
}
