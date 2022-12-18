module scale::in {
    use scale::account::{Self, Account};
    use scale::admin::{Self, AdminCap, ScaleAdminCap};
    use scale::position::{Self, Position};
    use scale::market::{Self, MarketList,Market};
    use scale::nft::{Self, ScaleNFTFactory,ScaleNFT,UpgradeMoveToken};
    use sui::tx_context::{TxContext};
    use sui::object::ID;
    use sui::coin::Coin;
    use std::option;

    public entry fun create_account<T>(
        token: &Coin<T>,
        ctx: &mut TxContext
    ) {
        account::create_account(token, ctx);
    }
    /// If amount is 0, the whole coin will be consumed
    public entry fun deposit<T>(
        account: &mut Account<T>,
        token: Coin<T>,
        amount: u64,
        ctx: &mut TxContext
    ){
        account::deposit(account, token, amount, ctx);
    }

    public entry fun withdrawal<P,T>(
        market_list: &MarketList,
        account: &mut Account<T>,
        amount: u64,
        ctx: &mut TxContext
    ){
        account::withdrawal<P,T>(position::get_equity<P,T>(market_list, account),account,amount,ctx);
    }
    public entry fun add_admin_member(
        admin_cap:&mut ScaleAdminCap,
        addr: address,
        ctx: &mut TxContext
    ){
        admin::add_admin_member(admin_cap,addr,ctx);
    }
    
    public entry fun remove_admin_member(
        admin_cap:&mut ScaleAdminCap,
        addr: address,
        ctx: &mut TxContext
    ){
        admin::remove_admin_member(admin_cap,addr,ctx);
    }
    public entry fun update_max_leverage<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        max_leverage: u8,
        ctx: &mut TxContext
    ){
        market::update_max_leverage(pac,market,max_leverage,ctx);
    }

    public entry fun update_insurance_fee<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        insurance_fee: u64,
        ctx: &mut TxContext
    ){
        market::update_insurance_fee(pac,market,insurance_fee,ctx);
    }

    public entry fun update_margin_fee<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        margin_fee: u64,
        ctx: &mut TxContext
    ){
        market::update_margin_fee(pac,market,margin_fee,ctx);
    }
    public entry fun update_fund_fee<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        fund_fee: u64,
        manual: bool,
        ctx: &mut TxContext
    ){
        market::update_fund_fee(pac,market,fund_fee,manual,ctx);
    }
    public entry fun update_status<P,T>(
        pac: &mut ScaleAdminCap,
        market: &mut Market<P,T>,
        status: u8,
        ctx: &mut TxContext
    ){
        market::update_status(pac,market,status,ctx);
    }

    public entry fun update_description<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        description: vector<u8>,
        ctx: &mut TxContext
    ){
        market::update_description(pac,market,description,ctx);
    }

    public entry fun update_spread_fee<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        spread_fee: u64,
        manual: bool,
        ctx: &mut TxContext
    ){
        market::update_spread_fee(pac,market,spread_fee,manual,ctx);
    }
    /// Update the officer of the market
    /// Only the contract creator has permission to modify this item
    public entry fun update_officer<P,T>(
        cap:&mut AdminCap,
        market:&mut Market<P,T>,
        officer: bool,
        ctx: &mut TxContext
    ){
        market::update_officer(cap,market,officer,ctx);
    }

    /// When the robot fails to update the price, update manually
    public entry fun update_oping_price<P,T>(
        cap:&mut AdminCap,
        market:&mut Market<P,T>,
        opening_price: u64,
        ctx: &mut TxContext
    ){
        market::update_oping_price(cap,market,opening_price,ctx);
    }

    /// The robot triggers at 0:00 every day to update the price of the day
    public entry fun trigger_update_opening_price<P,T>(
        market: &mut Market<P,T>,
        ctx: &mut TxContext
    ){
        market::trigger_update_opening_price(market,ctx);
    }
        /// Project side add NFT style
    public entry fun add_factory_mould(
        admin_cap:&mut AdminCap,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ){
        nft::add_factory_mould(admin_cap,factory,name,description,url,ctx);
    }

    public entry fun remove_factory_mould(
        admin_cap: &mut AdminCap,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        ctx: &mut TxContext
    ){
        nft::remove_factory_mould(admin_cap,factory,name,ctx);
    }
    public entry fun investment<P,T>(
        market: &mut Market<P,T>,
        token: Coin<T>,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        ctx: &mut TxContext
    ){
        nft::investment(market,token,factory,name,ctx);
    }
    /// Normal withdrawal of investment
    public entry fun divestment<P,T>(
        market: &mut Market<P,T>,
        nft: ScaleNFT<P,T>,
        ctx: &mut TxContext
    ){
        nft::divestment(market,nft,option::none(),ctx);
    }
    /// Generate transfer vouchers for NFT, transfer funds to new contracts when upgrading contracts, 
    /// and there will be no liquidated damages
    /// run in v2
    public entry fun generate_upgrade_move_token<P,T>(
        admin_cap: &mut AdminCap,
        nft: &ScaleNFT<P,T>,
        expiration_time: u64,
        addr: address,
        ctx: &mut TxContext,
    ){
        nft::generate_upgrade_move_token(admin_cap,nft,expiration_time,addr,ctx);
    }
    /// This may happen during version upgrade, and no penalty will be incurred
    /// run in v2
    public entry fun divestment_by_upgrade<P,T>(
        market: &mut Market<P,T>,
        nft: ScaleNFT<P,T>,
        move_token: UpgradeMoveToken,
        ctx: &mut TxContext
    ){
        nft::divestment_by_upgrade(market,nft,move_token,ctx);
    }

    public entry fun open_position<P,T>(
        market_list: &mut MarketList,
        market_id: ID,
        account: &mut Account<T>,
        lot: u64,
        leverage: u8,
        position_type: u8,
        direction: u8,
        ctx: &mut TxContext
    ){
        position::open_position<P,T>(market_list,market_id,account,lot,leverage,position_type,direction,ctx);
    }

    public entry fun close_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position: &mut Position<T>,
        ctx: &mut TxContext,
    ){
        position::close_position(market,account,position,ctx);
    }

    public entry fun burst_position<P,T>(
        market_list: &mut MarketList,
        account: &mut Account<T>,
        position: &mut Position<T>,
        ctx: &mut TxContext,
    ){
        position::burst_position<P,T>(market_list,account,position,ctx);
    }
}