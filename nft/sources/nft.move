module scale_nft::nft{
    use sui::tx_context::{sender, TxContext};
    use std::string::{Self,utf8, String};
    use sui::transfer;
    use sui::object::{Self, UID, ID};
    use sui::package;
    use sui::display;
    use std::vector;
    use sui::event;

    const ENameRequired: u64 = 1;
    const EDescriptionRequired: u64 = 2;
    const EUrlRequired: u64 = 3;
    const EDescriptionTooLong: u64 = 4;
    const EUrlTooLong: u64 = 5;
    const ENameTooLong: u64 = 6;

    struct Created<phantom T> has copy, drop {
        id: ID,
    }

    struct Delete<phantom T> has copy, drop {
        id: ID,
    }

    struct AdminCap has key {
        id: UID
    }

    struct ScaleProtocol has key, store {
        id: UID,
        name: String,
        description: String,
        img_url: String,
    }
    struct NFT has drop {}

    fun init(otw: NFT, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            utf8(b"{name}"),
            utf8(b"https://clutchy.io/marketplace/item/{id}"),
            utf8(b"{img_url}"),
            utf8(b"{description}"),
            utf8(b"https://scale.exchange"),
            utf8(b"Scale Protocol Team"),
        ];
        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<ScaleProtocol>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(display, sender(ctx));
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        },sender(ctx));
    }

    fun mint_(name:vector<u8>,description:vector<u8>,img_url:vector<u8>,ctx: &mut TxContext): ScaleProtocol {
        assert!(!vector::is_empty(&name), ENameRequired);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        assert!(!vector::is_empty(&img_url), EUrlRequired);
        assert!(vector::length(&name) < 50, ENameTooLong);
        assert!(vector::length(&description) < 240, EDescriptionTooLong);
        assert!(vector::length(&img_url) < 280, EUrlTooLong);
        ScaleProtocol{
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            img_url: string::utf8(img_url),
        }
    }

    public entry fun mint(
        _cap: &mut AdminCap,
        name:vector<u8>,
        description:vector<u8>,
        img_url:vector<u8>,
        ctx: &mut TxContext,
    ){
        let nft = mint_(name,description,img_url,ctx);
        event::emit(Created<ScaleProtocol> { id: object::id(&nft) });
        transfer::transfer(nft, sender(ctx));
    }

    public entry fun mint_multiple(
        _cap: &mut AdminCap,
        name:vector<u8>,
        description:vector<u8>,
        img_url:vector<u8>,
        amount: u64,
        ctx: &mut TxContext
    ){
        let i = 0;
        let nft = mint_(name,description,img_url,ctx);
        let ScaleProtocol{id, name, description, img_url} = nft;
        while (i < amount) {
            let uid = object::new(ctx);
            event::emit(Created<ScaleProtocol> { id: object::uid_to_inner(&uid) });
            transfer::transfer(ScaleProtocol{
                id: uid,
                name: name,
                description: description,
                img_url: img_url,
            }, sender(ctx));
            i = i + 1;
        };
        object::delete(id);
    }

    public entry fun mint_recipient(
        _cap: &mut AdminCap,
        name:vector<u8>,
        description:vector<u8>,
        img_url:vector<u8>,
        recipient: address,
        ctx: &mut TxContext,
    ){
        let nft = mint_(name,description,img_url,ctx);
        event::emit(Created<ScaleProtocol> { id: object::id(&nft) });
        transfer::transfer(nft, recipient);
    }

    public entry fun mint_multiple_recipient(
        _cap: &mut AdminCap,
        name:vector<u8>,
        description:vector<u8>,
        img_url:vector<u8>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ){
        let i = 0;
        let nft = mint_(name,description,img_url,ctx);
        let ScaleProtocol{id, name, description, img_url} = nft;
        while (i < amount) {
            let uid = object::new(ctx);
            event::emit(Created<ScaleProtocol> { id: object::uid_to_inner(&uid) });
            transfer::transfer(ScaleProtocol{
                id: uid,
                name: name,
                description: description,
                img_url: img_url,
            }, recipient);
            i = i + 1;
        };
        object::delete(id);
    }
    
    public entry fun burn(
        _cap: &mut AdminCap,
        nft: ScaleProtocol,
        _ctx: &mut TxContext,
    ){
        event::emit(Delete<ScaleProtocol> { id: object::id(&nft) });
        let ScaleProtocol{id, name:_, description:_, img_url:_} = nft;
        object::delete(id);
    }
}