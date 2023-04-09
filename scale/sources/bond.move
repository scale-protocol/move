module scale::bond {
    use sui::object::{Self,UID,ID};
    use std::string::{Self,String};
    use sui::url::{Self, Url};
    use sui::balance::{Balance};
    use scale::pool::{Self,LSP};
    use scale::market::{Self,Market};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self,TxContext};
    use std::vector;
    use sui::transfer;
    use sui::table::{Self,Table};
    use scale::admin::AdminCap;
    use sui::dynamic_field as field;
    use std::option::{Self,Option};
    use scale::event;
    // use scale_v1::nft;

    const ENameRequired:u64 = 401;
    const EDescriptionRequired:u64 = 402;
    const EUrlRequired:u64 = 403;
    const EInvalidNFTID:u64 = 404;
    const EInvalidMarketID:u64 = 405;
    const EInsufficientCoins:u64 = 406;
    /// scale nft
    struct ScaleBond<phantom P, phantom T> has key ,store {
        id: UID,
        name: String,
	    description: String,
	    url: Url,
        mint_time: u64,
        face_value: Balance<LSP<P,T>>,
        issue_expiration_time: u64,
        market_id: ID,
    }
    /// The scale nft factory stores some token templates and styles
    struct ScaleNFTFactory has key {
        id: UID,
        mould: Table<String,ScaleNFTItem>
    }
    /// The scale nft item
    struct ScaleNFTItem has store {
        name: String,
	    description: String,
	    url: Url,
    }

    /// Asset transfer voucher, used for asset transfer during contract upgrade
    struct MoveToken has store {
        nft_id: ID,
        expiration_time: u64
    }
    /// Generated by the target program upgraded to
    struct UpgradeMoveToken has key,store {
        id: UID,
        move_token: MoveToken,
    }

    fun init(ctx: &mut TxContext){
        transfer::share_object(ScaleNFTFactory{
            id: object::new(ctx),
            mould: table::new<String,ScaleNFTItem>(ctx),
        })
    }

    public fun generate_move_token<P,T>(
        _admin_cap: &mut AdminCap,
        nft: &ScaleBond<P,T>,
        expiration_time: u64,
        _ctx: &mut TxContext,
    ): MoveToken {
        MoveToken{
            nft_id:object::uid_to_inner(&nft.id),
            expiration_time,
        }
    }
    
    /// Withdraw funds from the current pool and destroy NFT bond certificates
    public fun divestment<P,T>(
        market: &mut Market<P,T>,
        nft: ScaleBond<P,T>,
        move_token: Option<MoveToken>,
        ctx: &mut TxContext
    ){
        let ScaleBond<P,T> {
            id,
            name:_,
            description:_,
            url:_,
            mint_time:_,
            face_value,
            issue_expiration_time:_,
            market_id,
        } = nft;
        assert!(market_id == object::id(market), EInvalidMarketID);
        // todo: check the expiration time .....
        if (option::is_some(&move_token)){
            // todo: Exempt from liquidated damages and give certain rewards if possible
            let MoveToken {nft_id,expiration_time:_} = option::destroy_some(move_token);
            assert!(object::uid_to_inner(&id) == nft_id, EInvalidNFTID);
        }else{            
            option::destroy_none(move_token);
        };
        transfer::public_transfer(pool::remove_liquidity(market::get_pool_mut(market),face_value,ctx),tx_context::sender(ctx));
        object::delete(id);
    }
    /// Project side add NFT style
    public fun add_factory_mould(
        _admin_cap:&mut AdminCap,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        _ctx: &mut TxContext
    ) {
        assert!(!vector::is_empty(&name), ENameRequired);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        assert!(!vector::is_empty(&url), EUrlRequired);
        let name = string::utf8(name);
        table::add(&mut factory.mould,name,ScaleNFTItem{
            name,
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
        });
    }

    /// Project side delete NFT style
    public fun remove_factory_mould(
        _admin_cap:&mut AdminCap,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        _ctx: &mut TxContext
    ) {
        assert!(!vector::is_empty(&name), ENameRequired);
        let ScaleNFTItem {name:_,description:_,url:_} = table::remove(&mut factory.mould,string::utf8(name));
    }

    /// Provide current pool funds and obtain NFT bond certificates
    public fun investment<P,T>(
        market: &mut Market<P,T>,
        token: Coin<T>,
        factory: &mut ScaleNFTFactory,
        name: vector<u8>,
        amount: u64,
        ctx: &mut TxContext
    ){
        let coins = coin::zero<T>(ctx);
        if (amount == 0){
            coin::join(&mut coins,token);
        }else{
            assert!(amount <= coin::value(&token), EInsufficientCoins);
            coin::join(&mut coins,coin::split(&mut token, amount, ctx));
            transfer::public_transfer(token,tx_context::sender(ctx));
        };
        // assert!(!vector::is_empty(&name), ENameRequired);
        let mould = table::borrow(&factory.mould,string::utf8(name));
        let uid = object::new(ctx);

        // Index all existing NFTs for interest distribution
        field::add(&mut factory.id,object::uid_to_inner(&uid),true);
        transfer::transfer(ScaleBond<P,T> {
            id: uid,
            name: mould.name,
            description: mould.description,
            url: mould.url,
            mint_time: 0,
            face_value: coin::into_balance(pool::add_liquidity(market::get_pool_mut(market),coins,ctx)),
            issue_expiration_time: 0,
            market_id: object::id(market),
        },tx_context::sender(ctx));
        event::update<Market<P,T>>(object::id(market));
    }

    /// Generate transfer vouchers for NFT, transfer funds to new contracts when upgrading contracts, 
    /// and there will be no liquidated damages
    /// run in v2
    public fun generate_upgrade_move_token<P,T>(
        admin_cap: &mut AdminCap,
        nft: &ScaleBond<P,T>,
        expiration_time: u64,
        addr: address,
        ctx: &mut TxContext,
    ) {
        transfer::transfer(UpgradeMoveToken{
            id: object::new(ctx),
            move_token: generate_move_token(admin_cap,nft,expiration_time,ctx),
        },addr);
    }

    /// This may happen during version upgrade, and no penalty will be incurred
    /// run in v2
    public fun divestment_by_upgrade<P,T>(
        market: &mut Market<P,T>,
        nft: ScaleBond<P,T>,
        move_token: UpgradeMoveToken,
        ctx: &mut TxContext
    ){
        let UpgradeMoveToken {id,move_token} = move_token;
        divestment(market,nft,option::some(move_token),ctx);
        object::delete(id);
    }
}