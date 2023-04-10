module scale::nft{
    use sui::tx_context::{sender, TxContext};
    use std::string::{Self,utf8, String};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::package;
    use sui::display;
    use scale::admin::AdminCap;
    use std::vector;
    use scale::event;

    const ENameRequired: u64 = 700;
    const EDescriptionRequired: u64 = 701;
    const EUrlRequired: u64 = 702;
    const EDescriptionTooLong: u64 = 703;
    const EUrlTooLong: u64 = 704;
    const ENameTooLong: u64 = 705;

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
            utf8(b"scale protocol team"),
        ];
        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<ScaleProtocol>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(display, sender(ctx));
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
        event::create<ScaleProtocol>(object::id(&nft));
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
            event::create<ScaleProtocol>(object::uid_to_inner(&uid));
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
        event::create<ScaleProtocol>(object::id(&nft));
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
            event::create<ScaleProtocol>(object::uid_to_inner(&uid));
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
}