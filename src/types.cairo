use starknet::ContractAddress;




// #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
// pub struct UserDetails {
//     pub user_address: ContractAddress,
//     pub addresses_len: u32,
// }


//#[derive(Copy, Drop, starknet::Store, Serde, PartialEq)]pub struct OrganizationDetails{

    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::traits::Into;
    use core::array::ArrayTrait;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};  
    use core::starknet::storage; 
    use starknet::storage::{StorageBase, FlattenedStorage, StorageTrait, StorageTraitMut};
    use starknet::storage::StoragePointer;



    // #[derive(Drop, Clone, Serde, starknet::Store, PartialEq)]
    // struct OrganizationDetails {
    //     organization_name: felt252,
    //     organization_address: ContractAddress,
    //     token_address: ContractAddress,
    //     employees: Array<ContractAddress>,
    //     amount_to_be_paid: Array<u256>,
    //     payment_interval: u64,
    //     start_time: u64,
    //     end_time: u64,
    //     is_payment_active: bool
    // }


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
   pub is_payment_active: bool
}


