use starknet::{ContractAddress, contract_address_const, get_contract_address, ClassHash};
use payrous_starknet::payrous::{IPayrousDispatcher, IPayrousDispatcherTrait};
use payrous_starknet::payrous_factory::{IPayrousFactoryDispatcher, IPayrousFactoryDispatcherTrait};


use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

// Helper function to get a constant contract address for testing
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}


const pay_class_hash: felt252 = 0x07b30b13c4fe5572699ee6bb6c49bff90c826fd21fbc18686d6f767d2d74a605;

fn deploy_contract(name: ByteArray) -> (ContractAddress, ContractAddress) {
    let owner: ContractAddress = owner();
    let contract = declare(name).unwrap().contract_class();
    let erc20_contract = declare("MyToken").unwrap().contract_class();

    let total_supply = 1000000.into();

    let erc20_calldata = array![total_supply, owner.into()];
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
    let hash_in_felt: felt252 = hash.try_into().unwrap();

    assert(hash_in_felt == pay_class_hash, 'Invalid hash');
}

#[test]
fn test_deploy_payrous_contract() {
    let (contract_address, erc20_contract_address) = deploy_contract("PayrousFactory");

    let dispatcher = IPayrousFactoryDispatcher { contract_address };

    // //payrous details for kenneth organisation 1
    let organization_name: felt252 = 'kenneth';
    let org_owner: ContractAddress = contract_address_const::<'kenneth'>();
    let platform_fee_recipient: ContractAddress = owner();
    let token_address: ContractAddress = erc20_contract_address;

    let payrous_contract_address = dispatcher.deploy_payrous(
        organization_name, 
        token_address.into(),
        org_owner.try_into().unwrap(), 
        platform_fee_recipient.try_into().unwrap()
    );

    let all_contract = dispatcher.get_all_deployed_contract();
    assert(all_contract.len() == 1, 'Invalid deployment');

    // let payrous_dispatcher = IPayrousDispatcher { contract_address: payrous_contract_address };

    // let payrous_owner = payrous_dispatcher.get_owner();
    // assert(payrous_owner == org_owner, 'Invalid owner');
}



