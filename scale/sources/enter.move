module scale::enter {
    use scale::account::{Self, Account};
    use scale::admin::{Self, AdminCap, ScaleAdminCap};
    use scale::position;
    use scale::market::{Self, List, Market};
    use scale::bond::{Self, BondFactory,ScaleBond};
    use sui::tx_context::{Self,TxContext};
    use sui::coin::Coin;
    use sui::object::ID;
    use sui::dynamic_object_field as dof;
    use oracle::oracle;
    use std::vector;
    use sui::pay;
    use scale::pool::{Self,Scale};
    use sui::package::Publisher;
    use sui::clock::Clock;
    use std::string;

    public entry fun create_account<T>(
        ctx: &mut TxContext
    ) {
        account::create_account<T>(ctx);
    }
    /// If amount is 0, the whole coin will be consumed
    public entry fun deposit<T>(
        account: &mut Account<T>,
        coins: vector<Coin<T>>,
        amount: u64,
        ctx: &mut TxContext
    ){
        let token = vector::pop_back(&mut coins);
        pay::join_vec(&mut token, coins);
        account::deposit(account, token, amount, ctx);
    }

    public entry fun withdrawal<T>(
        list: &List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        amount: u64,
        c: &Clock,
        ctx: &mut TxContext
    ){
        let total_liquidity = pool::get_total_liquidity<Scale,T>(market::get_pool(list));
        account::withdrawal<T>(position::get_equity<T>(total_liquidity,list, account,state,c),account,amount,ctx);
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
    
    public entry fun create_lsp<T>(
        _cap: &mut AdminCap,
        publisher: &Publisher,
        ctx: &mut TxContext
    ){
        market::create_list<T>(ctx);
        bond::create_display<T>(publisher,ctx)
    }

    public entry fun create_market<T>(
        list: &mut List<T>,
        symbol: vector<u8>,
        icon: vector<u8>,
        description: vector<u8>,
        size: u64,
        opening_price: u64,
        ctx: &mut TxContext
    ){
        market::create_market<T>(list,symbol,icon,description,size,opening_price,ctx);
    }

    public entry fun update_max_leverage<T>(
        symbol: vector<u8>,
        max_leverage: u8,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_max_leverage(pac,market,max_leverage,ctx);
    }

    public entry fun update_insurance_fee<T>(
        symbol: vector<u8>,
        insurance_fee: u64,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_insurance_fee(pac,market,insurance_fee,ctx);
    }

    public entry fun update_margin_fee<T>(
        symbol: vector<u8>,
        margin_fee: u64,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_margin_fee(pac,market,margin_fee,ctx);
    }

    public entry fun update_fund_fee<T>(
        symbol: vector<u8>,
        fund_fee: u64,
        manual: bool,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_fund_fee(pac,market,fund_fee,manual,ctx);
    }
    
    public entry fun update_status<T>(
        symbol: vector<u8>,
        status: u8,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_status(pac,market,status,ctx);
    }

    public entry fun update_description<T>(
        symbol: vector<u8>,
        description: vector<u8>,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_description(pac,market,description,ctx);
    }

    public entry fun update_icon<T>(
        symbol: vector<u8>,
        icon: vector<u8>,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_icon(pac,market,icon,ctx);
    }

    public entry fun update_spread_fee<T>(
        symbol: vector<u8>,
        spread_fee: u64,
        manual: bool,
        pac: &mut ScaleAdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::update_spread_fee(pac,market,spread_fee,manual,ctx);
    }
    /// Update the officer of the market
    /// Only the contract creator has permission to modify this item
    public entry fun update_officer<T>(
        officer: u8,
        cap: &mut AdminCap,
        list: &mut List<T>,
        ctx: &mut TxContext
    ){
        market::update_officer(cap,list,officer,ctx);
    }

    /// The robot triggers at 0:00 every day to update the price of the day
    public entry fun trigger_update_opening_price<T>(
        symbol: vector<u8>,
        list: &mut List<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ){
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),string::utf8(symbol));
        market::trigger_update_opening_price(market, state, c,ctx);
    }
    /// Project side add NFT style
    public entry fun add_factory_mould(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        ctx: &mut TxContext
    ){
        bond::add_factory_mould(admin_cap,factory,name,description,url,ctx);
    }

    public entry fun remove_factory_mould(
        name: vector<u8>,
        admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        ctx: &mut TxContext
    ){
        bond::remove_factory_mould(admin_cap,factory,name,ctx);
    }
    public entry fun update_penalty_fee(
        penalty_fee: u64,
        admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        _ctx: &TxContext
    ){
        bond::set_penalty_fee(admin_cap,factory,penalty_fee);
    }
    public entry fun investment<T>(
        coins: vector<Coin<T>>,
        nft_name: vector<u8>,
        amount: u64,
        issue_time_ms: u64,
        list: &mut List<T>,
        factory: &mut BondFactory,
        c: &Clock,
        ctx: &mut TxContext
    ){
        let token = vector::pop_back(&mut coins);
        pay::join_vec(&mut token, coins);
        bond::investment(token,nft_name,amount,issue_time_ms,list,factory,c,ctx);
    }
    /// Normal withdrawal of investment
    public entry fun divestment<T>(
        nft: ScaleBond<T>,
        list: &mut List<T>,
        factory: &mut BondFactory,
        c: &Clock,
        ctx: &mut TxContext
    ){
        bond::divestment(nft,list,factory,c,ctx);
    }

    public entry fun open_cross_position<T>(
        symbol: vector<u8>,
        lot: u64,
        leverage: u8,
        direction: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ){
        position::open_position<T>(symbol,lot,leverage,direction,1u8,auto_open_price,stop_surplus_price,stop_loss_price,list,account,state,c,ctx);
    }

    public entry fun open_isolated_position<T>(
        symbol: vector<u8>,
        lot: u64,
        leverage: u8,
        direction: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        coins: vector<Coin<T>>,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ){
        account::isolated_deposit(account,coins);
        position::open_position<T>(symbol,lot,leverage,direction,2u8,auto_open_price,stop_surplus_price,stop_loss_price,list,account,state,c,ctx);
        account::isolated_withdraw(account,tx_context::sender(ctx),ctx);
    }

    public entry fun close_position<T>(
        position_id: ID,
        lot: u64,
        state: &oracle::State,
        account: &mut Account<T>,
        list: &mut List<T>,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        position::close_position<T>(position_id,lot,state,account,list,c,ctx);
        account::isolated_withdraw(account,tx_context::sender(ctx),ctx);
    }

    public entry fun auto_close_position<T>(
        position_id: ID,
        state: &oracle::State,
        account: &mut Account<T>,
        list: &mut List<T>,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        position::auto_close_position<T>(position_id,state,account,list,c,ctx);
        account::isolated_withdraw(account,tx_context::sender(ctx),ctx);
    }

    public entry fun force_liquidation<T>(
        position_id: ID,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        position::force_liquidation<T>(position_id,list,account,state,c,ctx);
        account::isolated_withdraw(account,tx_context::sender(ctx),ctx);
    }

    public entry fun process_fund_fee<T>(
        list: &mut List<T>,
        account: &mut Account<T>,
        _ctx: &TxContext,
    ){
        position::process_fund_fee<T>(list,account,_ctx);
    }

    public entry fun update_cross_limit_position<T>(
        position_id: ID,
        lot: u64,
        leverage: u8,
        auto_open_price: u64,
        list: &mut List<T>,
        account: &mut Account<T>,
        ctx: &mut TxContext,
    ){
        position::update_limit_position<T>(position_id,lot,leverage,auto_open_price,list,account,ctx);
    }
    
    public entry fun update_isolated_limit_position<T>(
        position_id: ID,
        lot: u64,
        leverage: u8,
        auto_open_price: u64,
        coins: vector<Coin<T>>,
        list: &mut List<T>,
        account: &mut Account<T>,
        ctx: &mut TxContext,
    ){
        account::isolated_deposit(account,coins);
        position::update_limit_position<T>(position_id,lot,leverage,auto_open_price,list,account,ctx);
        account::isolated_withdraw(account,tx_context::sender(ctx),ctx);
    }

    public entry fun open_limit_position<T>(
        position_id: ID,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        _ctx: &mut TxContext,
    ){
        position::open_limit_position<T>(position_id,list,account,state,c,_ctx);
    }
    
    public entry fun update_automatic_price<T>(
        position_id: ID,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        account: &mut Account<T>,
        ctx: &mut TxContext,
    ){
        position::update_automatic_price<T>(position_id,stop_surplus_price,stop_loss_price,account,ctx);
    }

    public entry fun isolated_deposit<T>(
        position_id: ID,
        amount: u64,
        coins: vector<Coin<T>>,
        account: &mut Account<T>,
        list: &mut List<T>,
        ctx: &mut TxContext,
    ){        
        let token = vector::pop_back(&mut coins);
        pay::join_vec(&mut token, coins);
        position::isolated_deposit<T>(position_id,token,amount,account,list,ctx);
    }
}