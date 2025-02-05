use starknet::{ContractAddress, contract_address_const, get_contract_address, ClassHash};
use payrous_starknet::payrous::{IPayrousDispatcher, IPayrousDispatcherTrait};
use payrous_starknet::payrous_factory::{IPayrousFactoryDispatcher, IPayrousFactoryDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};



use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

// Helper function to get a constant contract address for testing
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}


const pay_class_hash: felt252 = 0x03941bf061599751ff803a9f281c51f09f0624e680fcacded761a1997d139185;

fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
    let owner: ContractAddress = owner();
    let contract = declare(name).unwrap().contract_class();
    let erc20_contract = declare("MyToken").unwrap().contract_class();

    let total_supply: u256 = 100000000000000000000 * 1000000;

    let erc20_calldata: Array::<felt252> = array![total_supply.low.into(),total_supply.high.into(), owner.into()];
    let constructor_calldata = array![owner.into(), pay_class_hash.into()];

    // let mut constructor_calldata: Array::<felt252> = array![owner.into(), pay_class_hash.into()];

    let (erc20_contract_address, _) = erc20_contract.deploy(@erc20_calldata).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, erc20_contract_address)
}



#[test]
fn test_succesfull_deployment() {
    let (contract_address, erc20_contract_address) = deploy_contract("PayrousFactory");

    let dispatcher = IPayrousFactoryDispatcher { contract_address };

    let all_contract = dispatcher.get_all_deployed_contract();
    assert(all_contract.len() == 0, 'Invalid deployment');

    let hash = dispatcher.get_class_hash();
    let hash_in_felt: ClassHash = hash.try_into().unwrap();
    let pay_class_hash_class: ClassHash = pay_class_hash.try_into().unwrap();

    assert(hash_in_felt == pay_class_hash_class, 'Invalid hash');
}

// #[test]
// #[fork("SEPOLIA_LATEST")]
// fn test_deploy_payrous_contract() {
//     let (payrous_factory_address, erc20_contract_address) = deploy_contract("PayrousFactory");

//     let dispatcher = IPayrousFactoryDispatcher { contract_address: payrous_factory_address };

//     //payrous details for kenneth organisation 1
//     let organization_name: felt252 = 'kenneth';
//     let org_owner: ContractAddress = contract_address_const::<'kenneth'>();
//     let platform_fee_recipient: ContractAddress = owner();

//     let payrous_contract_address = dispatcher.deploy_payrous(
//         organization_name, 
//         erc20_contract_address,
//         org_owner, 
//         platform_fee_recipient
//     );

//     let all_contract = dispatcher.get_all_deployed_contract();
//     assert(all_contract.len() == 1, 'Invalid deployment');

//     let payrous_dispatcher = IPayrousDispatcher { contract_address: payrous_contract_address };

//     let payrous_owner = payrous_dispatcher.get_owner();
//     assert(payrous_owner == org_owner, 'Invalid owner');
// }


// #[test]
// #[fork("SEPOLIA_LATEST")]
// fn test_add_multiple_users() {
//     let (payrous_factory_address, erc20_contract_address) = deploy_contract("PayrousFactory");

//     let dispatcher = IPayrousFactoryDispatcher { contract_address: payrous_factory_address };


//     //payrous details for kenneth organisation 1
//     let organization_name: felt252 = 'kenneth';
//     let org_owner: ContractAddress = owner();
//     let platform_fee_recipient: ContractAddress = owner();

//     let payrous_contract_address = dispatcher.deploy_payrous(
//         organization_name, 
//         erc20_contract_address,
//         org_owner, 
//         platform_fee_recipient
//     );

//     let all_contract = dispatcher.get_all_deployed_contract();
//     assert(all_contract.len() == 1, 'Invalid deployment');


//     let payrous_dispatcher = IPayrousDispatcher { contract_address: payrous_contract_address };

//     let payrous_owner = payrous_dispatcher.get_owner();
//     assert(payrous_owner == org_owner, 'Invalid owner');

//     //generate 500 user address and amount to be paid. use equal amount for all users
//     let mut user_addresses: Array::<ContractAddress> = ArrayTrait::new();

//     let mut i: u64 = 1;

//     while i < 501 {
//         let mut b: felt252 = i.into();

//         // let user_address = contract_address_const::<b>();
//         user_addresses.append(b.try_into().unwrap());
//         i += 1;
//     };

   
//     let amount_to_be_paid: u256 = 10000000000000000000;
//     let mut amount_to_be_paid_array: Array::<u256> = ArrayTrait::new();

//     let mut j: u64 = 0;
    
//     while j < 500 {
//         amount_to_be_paid_array.append(amount_to_be_paid);
//         j += 1;
//     };

//     start_cheat_caller_address(payrous_contract_address, payrous_owner);
//     payrous_dispatcher.add_multiple_employees(user_addresses, amount_to_be_paid_array);  
//     stop_cheat_caller_address(payrous_owner);

//     let all_users = payrous_dispatcher.get_all_employee_address();
//     assert(all_users.len() == 500, 'Invalid number of users');  
// }



#[test]
#[fork("SEPOLIA_LATEST")]
fn test_pay_multiple_users() {
    let (payrous_factory_address, erc20_contract_address) = deploy_contract("PayrousFactory");

    let dispatcher = IPayrousFactoryDispatcher { contract_address: payrous_factory_address };

    //payrous details for kenneth organisation 1
    let organization_name: felt252 = 'kenneth';
    let org_owner: ContractAddress = owner();
    let platform_fee_recipient: ContractAddress = owner();

    let payrous_contract_address = dispatcher.deploy_payrous(
        organization_name, 
        erc20_contract_address,
        org_owner, 
        platform_fee_recipient
    );

    let all_contract = dispatcher.get_all_deployed_contract();
    assert(all_contract.len() == 1, 'Invalid deployment');


    let payrous_dispatcher = IPayrousDispatcher { contract_address: payrous_contract_address };

    let payrous_owner = payrous_dispatcher.get_owner();
    assert(payrous_owner == org_owner, 'Invalid owner');

    //generate 500 user address and amount to be paid. use equal amount for all users
    let mut user_addresses: Array::<ContractAddress> = ArrayTrait::new();

    let mut i: u64 = 1;

    while i < 501 {
        let mut b: felt252 = i.into();

        // let user_address = contract_address_const::<b>();
        user_addresses.append(b.try_into().unwrap());
        i += 1;
    };

   
    let amount_to_be_paid: u256 = 1000;
    let mut amount_to_be_paid_array: Array::<u256> = ArrayTrait::new();

    let mut j: u64 = 0;
    
    while j < 500 {
        amount_to_be_paid_array.append(amount_to_be_paid);
        j += 1;
    };

    start_cheat_caller_address(payrous_contract_address, payrous_owner);
    payrous_dispatcher.add_multiple_employees(user_addresses, amount_to_be_paid_array);  
    stop_cheat_caller_address(payrous_owner);

    //give allowance to payrous contract
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract_address };
    let allowance_amount: u256 = 10000000000000000000 * 501;
    let total_supply: u256 = 100000000000000000000 * 1000000;

    // start_cheat_caller_address(payrous_contract_address, payrous_owner);
    // erc20_dispatcher.approve(payrous_contract_address, allowance_amount);
    // stop_cheat_caller_address(payrous_owner);

    println!("allowance_amount");
    println!("{}", allowance_amount);

    println!("total_supply");

    println!("{}", total_supply);

    // start_cheat_caller_address(payrous_contract_address, payrous_owner);
    // payrous_dispatcher.deposit(allowance_amount);
    // stop_cheat_caller_address(payrous_owner);


    println!("We don reach here 2");

    println!("balance of owner");
    println!("{}", erc20_dispatcher.balance_of(payrous_owner));
        
    //deposit allowance to payrous contract
    start_cheat_caller_address(erc20_contract_address, payrous_owner);
    erc20_dispatcher.transfer(payrous_contract_address, allowance_amount);
    stop_cheat_caller_address(payrous_owner);


    println!("Allowance deposited to the contract");

    assert_ge!(erc20_dispatcher.balance_of(payrous_contract_address), allowance_amount, "Invalid balance: wahala dey");


    println!("{}", erc20_dispatcher.balance_of(payrous_contract_address));


    // send to employee
    start_cheat_caller_address(payrous_contract_address, payrous_owner);
    payrous_dispatcher.send_to_employee();
    stop_cheat_caller_address(payrous_owner);

    println!("We don reach here 3");

    let all_users = payrous_dispatcher.get_all_employee_address();
    assert(all_users.len() == 500, 'Invalid number of users');  

    println!("We don reach here 4");
}



