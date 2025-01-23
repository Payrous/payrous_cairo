use starknet::ContractAddress;
use core::array::ArrayTrait;
use core::starknet::storage;


#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct UserDetails {
    pub user_address: ContractAddress,
    pub addresses_len: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct OrganizationDetails{
    pub organization_address: ContractAddress,
    pub token_address: ContractAddress,
    pub employees: Array<ContractAddress>,  
    pub amount_to_be_paid: Array<u256>,
    pub payment_interval: u256,
    pub start_time: u256,
    pub end_time: u256,
    pub is_payment_active: bool
}


