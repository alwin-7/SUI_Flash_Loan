module flash_loan::eth_coin;

use sui::coin_registry;
use sui::balance;

// Custom ETH Coin
public struct ETH_COIN has drop {}

#[allow(lint(share_owned))]
fun init(witness: ETH_COIN, ctx: &mut TxContext){
    let (metadata, treasury) = coin_registry::new_currency_with_otw(
        witness,
        9,
        b"ETH".to_string(),
        b"Ethereum".to_string(),
        b"x".to_string(),
        b"0".to_string(),
        ctx,
    );
    let metadata_cap = metadata.finalize(ctx);

    transfer::public_share_object(metadata_cap);
    transfer::public_transfer(treasury, ctx.sender());
}

#[test_only]
public fun testing_init(ctx: &mut TxContext){
    init(ETH_COIN{}, ctx);
}