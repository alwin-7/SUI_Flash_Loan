module flash_loan::flash_loan;

use sui::sui::SUI;
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::balance::value;
use flash_loan::eth_coin::ETH_COIN;
use sui::transfer::share_object;

// Error code
const ELoanAmountExceed: u64 = 0;
const ERepayAmountInvalid: u64 = 1;

// Init fun for creating shared pool object's
fun init(ctx: &mut TxContext){
    let pool = Pool {
        id: object::new(ctx),
        sui_coin: balance::zero<SUI>(),
        eth_coin: balance::zero<ETH_COIN>(),
    };

    let lender_pool = Lender { 
        id: object::new(ctx),
        amount: balance::zero<SUI>(),
    };

    share_object(pool);
    share_object(lender_pool);
}

// Lender pool object
public struct Lender has key {
    id: UID,
    amount: Balance<SUI>,
}

// Swap Pool object
public struct Pool has key {
    id: UID,
    sui_coin: Balance<SUI>,
    eth_coin: Balance<ETH_COIN>,
}

// Hot potato
// Makes sure, the borrowed amount repaid in the same transcation itself
public struct Loan {
    amount: u64,
}

// Borrow loan from the Lender
public fun borrow(lend: &mut Lender, amount: u64, ctx: &mut TxContext): (Coin<SUI>, Loan) {
    assert!(amount <= balance::value(&lend.amount),ELoanAmountExceed);

    (
        coin::from_balance(balance::split(&mut lend.amount, amount), ctx),
        Loan {
            amount
        }
    )
}

// Repay's the borrowed amount back to the Lender pool(obj)
#[allow(lint(self_transfer))]
public fun repay(lend: &mut Lender, loan: Loan, user_sui: Coin<SUI>, ctx:&mut TxContext) {
    
    let Loan { amount } = loan;
    assert!(coin::value(&user_sui) >= amount, ERepayAmountInvalid);

    let mut input_balance = coin::into_balance(user_sui);
    balance::join(
        &mut lend.amount,
        balance::split(&mut input_balance, amount),
    );
    // Transfers the balance after the re-payment of loan back to the user,
    //here we're transferring a new Coin<SUI> obj, but with updated values
    let excess_coin = coin::from_balance(input_balance, ctx);
    transfer::public_transfer(excess_coin, ctx.sender());
}

// Deposit SUI Coin to lender pool object
#[allow(lint(self_transfer))]
public fun deposit_sui_lender(
    pool: &mut Lender, 
    user_coin: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext,
    ) {
    let coin_value = user_coin.value();
    assert!(coin_value >= amount,0);

    let mut input_balance = coin::into_balance(user_coin);
    if (coin_value == amount) {
        balance::join(&mut pool.amount, input_balance);
    } else {
        balance::join(
            &mut pool.amount,
            balance::split(&mut input_balance, amount),
        );
        let excess_coin = coin::from_balance(input_balance, ctx);
        transfer::public_transfer(excess_coin, ctx.sender());
    };
}

// Deposit SUI Coin into the Pool
#[allow(lint(self_transfer))]
public fun deposit_sui(
    pool: &mut Pool, 
    user_coin: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext, 
    ) {
        let coin_value = user_coin.value();
        assert!(coin_value >= amount,0);

    let mut input_balance = coin::into_balance(user_coin);
    if (coin_value == amount) {
        balance::join(&mut pool.sui_coin, input_balance);
    } else {
        balance::join(
            &mut pool.sui_coin,
            balance::split(&mut input_balance, amount),
        );
        let excess_coin = coin::from_balance(input_balance, ctx);
        transfer::public_transfer(excess_coin, ctx.sender());
    };
}

// Deposit ETH Coin into the Pool
#[allow(lint(self_transfer))]
public fun deposit_eth(
    pool: &mut Pool, 
    user_coin: Coin<ETH_COIN>,
    amount: u64,
    ctx: &mut TxContext,
) {
    let coin_value = user_coin.value();
    assert!(coin_value >= amount,0);

    let mut input_balance = coin::into_balance(user_coin);
    if (coin_value == amount) {
        balance::join(&mut pool.eth_coin, input_balance);
    } else {
        balance::join(
            &mut pool.eth_coin,
            balance::split(&mut input_balance, amount),
        );
        let excess_coin = coin::from_balance(input_balance, ctx);
        transfer::public_transfer(excess_coin, ctx.sender());
    };
}

// Function that swaps SUI to ETH
#[allow(lint(self_transfer))]
public fun swap_sui_to_eth(
    pool: &mut Pool,
    user_coin: Coin<SUI>,
    mut user_eth: Coin<ETH_COIN>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<ETH_COIN> {
    // checks if the pool has this much of ETH_COIN
    // ratio 2:1 for 2 sui you get 1 eth
    let output_value = amount *  1000 / 2000;
    assert!(pool.eth_coin.value() >= output_value,1);

    deposit_sui(pool, user_coin, amount, ctx);

    let output_balance = balance::split(&mut pool.eth_coin, output_value);
    let output_coin = coin::from_balance(output_balance, ctx);
    coin::join(&mut user_eth, output_coin);
    user_eth
}

// Function that swaps ETH to SUI
#[allow(lint(self_transfer))]
public fun swap_eth_to_sui(
    pool: &mut Pool,
    mut user_coin: Coin<ETH_COIN>,
    mut user_sui: Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext,
): (Coin<ETH_COIN>, Coin<SUI>) {
    // checks if the pool has this much of SUI coin
    // ratio 1:3 for 1 eth you get 3 sui
    let output_value = amount *  3000 / 1000;
    assert!(pool.sui_coin.value() >= output_value,1);

    let coin_to_swap = coin::split(&mut user_coin, amount, ctx);
    deposit_eth(pool, coin_to_swap, amount, ctx);

    let output_balance = balance::split(&mut pool.sui_coin, output_value);
    let output_coin = coin::from_balance(output_balance, ctx);
    coin::join(&mut user_sui, output_coin);
    (user_coin, user_sui)
}

#[test_only]
public fun test_init(ctx: &mut TxContext){
    init(ctx);
}