#[test_only]
module oracle::pyth_network_tests{
    // use oracle::oracle;
    // use oracle::pyth_network;
    // use sui::test_scenario;
    // use pyth::setup;
    // use wormhole::setup::{Self as wormhole_setup, DeployerCap};
    // use wormhole::external_address::{Self};
    // use wormhole::bytes32::{Self};
    // use wormhole::state::{State as WormState};
    // use wormhole::vaa::{Self, VAA};
    // #[test]
    // fun test_update_price(){
    //     let owner = @0x1;
    //     let test_tx = test_scenario::begin(owner);
    //     let tx = &mut test_tx;
    //     let symbol_btc: vector<u8>;
    //     let symbol_eth: vector<u8>;
    //     let symbol_doge: vector<u8>;
    //     test_scenario::next_tx(tx,owner);
    //     {
    //         oracle::init_for_testing(test_scenario::ctx(tx));
    //         pyth_network::init_for_testing(test_scenario::ctx(tx));
    //         symbol_btc = b"Crypto.BTC/USD";
    //         symbol_eth = b"Crypto.ETH/USD";
    //         symbol_doge = b"Crypto.DOGE/USD";
    //         wormhole_setup::init_test_only(test_scenario::ctx(tx));
    //         setup::init_test_only(test_scenario::ctx(tx));
    //     };
    //     test_scenario::next_tx(tx,owner);
    //     {
    //         let o_s = test_scenario::take_shared<oracle::State>(tx);
    //         let p_s = test_scenario::take_shared<pyth_network::State>(tx);
    //         let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
    //     };
    //     test_scenario::end(test_tx);
    // }
}