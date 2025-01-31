use starknet::ContractAddress;

#[derive(Drop, Clone, Serde, starknet::Store, PartialEq)]
pub struct OrganizationDetails {
   pub  organization_name: felt252,
   pub  organization_address: ContractAddress,
   pub  token_address: ContractAddress,
   pub  employees_length: u32,  // Store the length separately
   pub  amount_to_be_paid_length: u32,
   pub  payment_interval: u64,
   pub  start_time: u64,
   pub  end_time: u64,
   pub is_payment_active: bool,
   pub deployed_at: u64,
}



#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct ContractInfo{
    pub contract_address: ContractAddress,
    pub deployment_time: u64,
    pub deployer: ContractAddress,
    pub contract_index: u64,
}




