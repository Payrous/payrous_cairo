use starknet::{ContractAddress, ClassHash};
use payrous_starknet::types::{ContractInfo};


#[starknet::interface]
pub trait IPayrousFactory<TContractState> {
    //read functions
    fn get_all_deployed_contract(self: @TContractState) -> Array<ContractAddress>;
    fn get_all_deployed_contract_by_user(self: @TContractState, user_address: ContractAddress) -> Array<ContractAddress>;
    fn get_a_contract_details(self: @TContractState, deployed_address: ContractAddress) -> ContractInfo;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_contract_info(self: @TContractState, contract_address: ContractAddress) -> ContractInfo;
    fn get_class_hash(self: @TContractState) -> ClassHash;


    //write functions
    fn deploy_payrous(
        ref self: TContractState, 
        organization_name: felt252, 
        token_address: ContractAddress, 
        owner: ContractAddress, 
        platform_fee_recipient: ContractAddress,
    );
    fn upgrade_class_hash(ref self: TContractState, new_class_hash: ClassHash);

}


#[starknet::contract]
pub mod PayrousFactory {
    use starknet::ContractAddress;
    use starknet::{
        syscalls::deploy_syscall,
        ClassHash,
        get_caller_address, 
        get_contract_address, 
        get_block_timestamp
    };
    use payrous_starknet::types::{ContractInfo};
    use payrous_starknet::payrous::{IPayrousDispatcher,IPayrousDispatcherTrait};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};  




    #[storage]
    struct Storage {
        owner: ContractAddress,
        total_deployed_contract: u64,
        total_users: u64,
        all_deployed_address: Map<u64, ContractAddress>,
        contract_info: Map<ContractAddress, ContractInfo>,
        user_deployed_tokens: Map<ContractAddress, Map<u32, ContractAddress>>, 
        user_token_count: Map<ContractAddress, u32>, 
        payrous_class_hash: ClassHash,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractCreated: ContractCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractCreated {
        #[key]
        token_address: ContractAddress,
        #[key]
        deployer: ContractAddress,
        #[key]
        time: u64,
        index: u32,
    }  

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress, _payrous_class_hash: felt252) {
        let payrous_hash: ClassHash = _payrous_class_hash.try_into().unwrap();
        self.owner.write(_owner);
        self.payrous_class_hash.write(payrous_hash);
    }


    #[abi(embed_v0)]
    impl PayrousFactoryImpl of super::IPayrousFactory<ContractState> {

        fn deploy_payrous( ref self: ContractState,  organization_name: felt252, token_address: ContractAddress, owner: ContractAddress, platform_fee_recipient: ContractAddress) {
            let contract_address = self._deploy_payrous(organization_name, token_address, owner, platform_fee_recipient, self.payrous_class_hash.read());
            self.all_deployed_address.entry(self.total_deployed_contract.read()).write(contract_address);

            let _contract_details = ContractInfo {
                contract_address: contract_address,
                deployment_time: get_block_timestamp(),
                deployer: owner,
                contract_index: self.total_deployed_contract.read().into() 
            };

            self.contract_info.entry(contract_address).write(_contract_details);

            let current_count = self.total_deployed_contract.read();
            self.all_deployed_address.entry(current_count).write(token_address);
            self.total_deployed_contract.write(current_count + 1);

            let count = self.user_token_count.entry(owner).read();

            self.user_deployed_tokens.entry(owner).entry(count).write(token_address);
            self.user_token_count.entry(owner).write(count + 1);
        }

        fn upgrade_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            assert!(self.get_owner() == get_caller_address(), "Only owner can upgrade the class hash");
            self.payrous_class_hash.write(new_class_hash);
        }

        fn get_all_deployed_contract(self: @ContractState) -> Array<ContractAddress> {
            let total_deployed = self.total_deployed_contract.read();
            let mut all_deployed: Array<ContractAddress> = ArrayTrait::new();
            let mut i: u64 = 0;

            loop {
                if i >= total_deployed {
                    break;
                }

                all_deployed.append(self.all_deployed_address.entry(i).read());
                i += 1;
            };
            all_deployed
        }


        fn get_all_deployed_contract_by_user(self: @ContractState, user_address: ContractAddress) -> Array<ContractAddress> {
            let total_deployed = self.user_token_count.entry(user_address).read();
            let mut all_deployed: Array<ContractAddress> = ArrayTrait::new();
            let mut i: u32 = 0;

            loop {
                if i >= total_deployed {
                    break;
                }

                all_deployed.append(self.user_deployed_tokens.entry(user_address).entry(i).read());
                i += 1;
            };
            all_deployed
        }

        fn get_a_contract_details(self: @ContractState, deployed_address: ContractAddress) -> ContractInfo {
            self.contract_info.entry(deployed_address).read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_contract_info(self: @ContractState, contract_address: ContractAddress) -> ContractInfo {
            self.contract_info.entry(contract_address).read()
        }

        fn get_class_hash(self: @ContractState) -> ClassHash {
            self.payrous_class_hash.read()
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _deploy_payrous(
            ref self: ContractState,
            organization_name: felt252, 
            token_address: ContractAddress,
            owner: ContractAddress, 
            platform_fee_recipient: ContractAddress, 
            payrous_class_hash: ClassHash
        ) -> ContractAddress {
            let payrous_hash: ClassHash = payrous_class_hash.try_into().unwrap();

            // let call_data: Array<felt252> = array![organization_name,token_address.into(),owner.into(),platform_fee_recipient.into()];
            let call_data: Array<felt252> = array![];

            // I REACH HERE

            
            
            let (contract_address, _) = deploy_syscall(
                payrous_hash.try_into().unwrap(),
                self.total_deployed_contract.read().into(),
                call_data.span(),
                false
            ).unwrap();

            IPayrousDispatcher{contract_address: contract_address}.initialize(organization_name, token_address, owner, platform_fee_recipient);

            contract_address
        }
    }

}