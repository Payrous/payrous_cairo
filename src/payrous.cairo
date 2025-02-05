use starknet::ContractAddress;
use payrous_starknet::types::OrganizationDetails;


#[starknet::interface]
pub trait IPayrous<TContractState> {
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

    // view functions
    fn get_organization_details(self: @TContractState) -> OrganizationDetails;
    fn get_employee_details(self: @TContractState, employee: ContractAddress) -> (u256, u64, u64);
    fn get_all_employee_address(self: @TContractState) -> Array<ContractAddress>;
    fn get_employee_count(self: @TContractState) -> u256;
    fn get_employee_balance(self: @TContractState, employee: ContractAddress) -> u256;
    fn get_contract_balance(self: @TContractState) -> u256;
    fn get_full_details(self: @TContractState) -> (OrganizationDetails, Array<ContractAddress>, Array<u256>);
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn initialize(ref self: TContractState,name: ByteArray, symbol: ByteArray, initial_supply: u256);
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256);
    fn transfer_from( ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    

}


#[starknet::contract]
mod Payrous {
    use super::IPayrous;
    use core::array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};  
    use payrous_starknet::errors;
    use core::num::traits::Zero;
    use payrous_starknet::types::OrganizationDetails;
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


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
        deployed_at: u64,
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
    impl PayrousImpl of super::IPayrous<ContractState> {
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
                is_payment_active: false,
                deployed_at: get_block_timestamp()
            };

            self.organizationDetails.write(_organizationDetails);

            self.initialized.write(true);
        }


        fn add_multiple_employees(ref self: ContractState, employees: Array<ContractAddress>, amounts: Array<u256>) {
            self._checkOwner();
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
            self._checkOwner();
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
            self._checkOwner();
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
            let mut current_details = self.organizationDetails.read();
            
            // Check end time if it's set
            if current_details.end_time != 0 {
                assert(get_block_timestamp() < current_details.end_time, errors::INVALID_TIME);
            }

            // Check start time and update interval
            assert(get_block_timestamp() >= current_details.start_time, errors::UNAUTHORIZED);
            
            // let mut updated_details = current_details;
            current_details.start_time += current_details.payment_interval;
            current_details.is_payment_active = true;
            
            // Check if there are employees
            assert(current_details.employees_length > 0, errors::EMPLOYEE_NOT_FOUND);

         
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
                // self.emit(ERC20Transfer { token_address: current_details.token_address, sender: get_caller_address(), to: recipient, amount: amount });  
                i += 1;
            };
            
            // Update organization details
            self.organizationDetails.write(current_details);
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

        fn deposit(ref self: ContractState, amount: u256) {
            assert(amount != 0, errors::INVALID_AMOUNT);
            let caller = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.organizationDetails.read().token_address };
            token.transfer_from(caller, get_contract_address(), amount);
            
            self.emit(ERC20Transfer { token_address: self.organizationDetails.read().token_address, sender: caller, to: get_contract_address(), amount });
        }

        fn update_payment_token(ref self: ContractState, token_address: ContractAddress) {
            self._checkOwner();
            assert(!token_address.is_zero(), errors::INVALID_ADDRESS);
            let mut current_details = self.organizationDetails.read();
            current_details.token_address = token_address;
            self.organizationDetails.write(current_details);
        }

        fn withdraw_locked_funds(ref self: ContractState, token_address: ContractAddress) {
            self._checkOwner();
            let token = IERC20Dispatcher { contract_address: token_address };
            let caller = get_caller_address();
            let total_amount = token.balance_of(get_contract_address());
            token.transfer(caller, total_amount);
            self.emit(ERC20Transfer { token_address, sender: get_contract_address(), to: caller, amount: total_amount });
        }

        fn update_platform_fee(ref self: ContractState, platform_fee: u256) {
            self._checkOwner();
            assert(platform_fee > 0, errors::INVALID_PLATFORM_FEES);
            self.platform_fee.write(platform_fee);
        }


        // read function
        fn get_organization_details(self: @ContractState) -> OrganizationDetails {
            self.organizationDetails.read()
        }

        fn get_employee_details(self: @ContractState, employee: ContractAddress) -> (u256, u64, u64) {

            let employee_index = self.employeeIndex.entry(employee).read();
            let amount = self.employee_amounts.entry(employee_index).read();
            let start_time = self.organizationDetails.read().start_time;
            let payment_interval = self.organizationDetails.read().payment_interval;
            (amount, start_time, payment_interval)
        }

        fn get_all_employee_address(self: @ContractState) -> Array<ContractAddress> {
            let mut employees: Array<ContractAddress> = array![];
            let mut i: u32 = 0;
            while i < self.organizationDetails.read().employees_length {
                employees.append(self.organization_employees.read(i));
                i += 1;
            };
            employees
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }


        fn get_employee_count(self: @ContractState) -> u256 {
            self.organizationDetails.read().employees_length.into()
        }

        fn get_employee_balance(self: @ContractState, employee: ContractAddress) -> u256 {
            let employee_index = self.employeeIndex.entry(employee).read();
            self.employee_amounts.entry(employee_index).read()
        }

        fn get_contract_balance(self: @ContractState) -> u256 {
            let token = IERC20Dispatcher { contract_address: self.organizationDetails.read().token_address };
            token.balance_of(get_contract_address())
        }

        fn get_full_details(self: @ContractState) -> (OrganizationDetails, Array<ContractAddress>, Array<u256>) {
            let organization_details = self.organizationDetails.read();
            let employees = self.get_all_employee_address();
            let mut amounts: Array<u256> = array![];
            let mut i: u32 = 0;
            while i < organization_details.employees_length {

                let employee = *employees[i];
                let employee_index = self.employeeIndex.entry(employee).read();
                amounts.append(self.employee_amounts.read(employee_index));
                i += 1;
            };
            (organization_details, employees, amounts)
        }
    }



    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _checkOwner(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), errors::UNAUTHORIZED);
        }
    }
  
}
