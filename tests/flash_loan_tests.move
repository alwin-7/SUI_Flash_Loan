#[test_only]
module flash_loan::flash_loan_tests;

use flash_loan::flash_loan;
use flash_loan::eth_coin;
use sui::test_scenario;
use sui::coin::TreasuryCap;
use sui::coin;
use flash_loan::eth_coin::ETH_COIN;
use sui::sui::SUI;
use flash_loan::flash_loan::Lender;
use sui::coin::Coin;
use flash_loan::flash_loan::Pool;
use std::debug;



// Flash loan test-case
// First we need to fund our user account with some SUI coin and
//ETH coin (eth_coin can be acquired via eth_coin module)
// Then we need to deposit some SUI to lender pool and swap pool,
//also some ETH to swap pool
// Now need to call the flash loan logic in one tx:
// call borrow -> swap_sui_to_eth -> swap_eth_to_sui -> repay

#[test]
fun test_flash_loan(){
    let user1 = @0xB;

    let mut scenario_val = test_scenario::begin(user1);
    let scenario = &mut scenario_val;

// Tx that create the lender pool object and swap pool object
    test_scenario::next_tx(scenario, user1);
    {
        flash_loan::test_init(test_scenario::ctx(scenario));
    };

// Tx that mint some SUI and sent it to our user1 
    test_scenario::next_tx(scenario, @0x0);
    {
        let s_coin = coin::mint_for_testing<SUI>(100, test_scenario::ctx(scenario));
        transfer::public_transfer(s_coin, user1);
    };

// Tx that create our custom coin ETH_COIN obj
    test_scenario::next_tx(scenario, user1);
    {
        eth_coin::testing_init(test_scenario::ctx(scenario));
    };

// Tx that mint our custom coin(ETH_COIN) and sent it to our user1 
    test_scenario::next_tx(scenario, user1);
    {
        let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<ETH_COIN>>(scenario);
        let e_coin = coin::mint(&mut treasurycap, 100, test_scenario::ctx(scenario));
        
        test_scenario::return_to_address<TreasuryCap<ETH_COIN>>(user1, treasurycap);
        transfer::public_transfer(e_coin, user1);
    };

// Tx that deposits SUI to Lender pool obj
    test_scenario::next_tx(scenario, user1);
    {
        let mut acc_lender = test_scenario::take_shared<Lender>(scenario);
        let acc_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
        flash_loan::deposit_sui_lender(&mut acc_lender , acc_coin, 25, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(acc_lender);
    };

// Tx that deposits, SUI and ETH to swap Pool obj
    test_scenario::next_tx(scenario, user1);
    {
        // Deposit SUI to Pool
        let mut swap_pool = test_scenario::take_shared<Pool>(scenario);
        let acc_sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
        flash_loan::deposit_sui(&mut swap_pool, acc_sui, 20, test_scenario::ctx(scenario));

        // Deposit ETH to Pool
        let acc_eth = test_scenario::take_from_sender<Coin<ETH_COIN>>(scenario);
        flash_loan::deposit_eth(&mut swap_pool, acc_eth, 20, test_scenario::ctx(scenario));

        test_scenario::return_shared(swap_pool);
    };

// user1 balance before flash loan call
    test_scenario::next_tx(scenario, user1);
    {
        let sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
        let eth = test_scenario::take_from_sender<Coin<ETH_COIN>>(scenario);

        debug::print(&b"Balances before Flash Loan".to_string());
        debug::print(&b"SUI:".to_string());
        debug::print(&sui.value());
        debug::print(&b"ETH:".to_string());
        debug::print(&eth.value());
        transfer::public_transfer(sui, user1);
        transfer::public_transfer(eth, user1);
    };

// Tx that executes flash loan
    test_scenario::next_tx(scenario, user1);
    {
        let mut lend_pool = test_scenario::take_shared<Lender>(scenario);
        let mut swap_pool = test_scenario::take_shared<Pool>(scenario);

        let acc_sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
        let acc_eth = test_scenario::take_from_sender<Coin<ETH_COIN>>(scenario);

        // calls the borrow function
        // we borrows 10 SUI from the Lender pool
        // returns Coin<SUI> and struct Loan (hot potato)
        let (coin_sui, hp_loan) = flash_loan::borrow(&mut lend_pool, 10, test_scenario::ctx(scenario));

        // calls the swap fn to swap sui to eth
        // uses the borrow fn, returned Coin<SUI> to swap
        // returns our updated ETH_COIN struct
        let acc_eth = flash_loan::swap_sui_to_eth(&mut swap_pool, coin_sui, acc_eth, 10, test_scenario::ctx(scenario));

        // Eg, trade for profit
        // now calls the eth_to_sui swap fn
        // this is the call where we gain a profit of 5 SUI
        // returns our updated ETH_COIN and SUI struct
        let (acc_eth, acc_sui) = flash_loan::swap_eth_to_sui(&mut swap_pool, acc_eth, acc_sui, 5, test_scenario::ctx(scenario));
        
        // here we will repay the borrowed loan which is 10 SUI
        // we repay's from our user1 owned Coin<SUI> balance
        flash_loan::repay(&mut lend_pool, hp_loan, acc_sui, test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, acc_eth);
        test_scenario::return_shared(lend_pool);
        test_scenario::return_shared(swap_pool);
    };

// user1 balance after flash loan call
    test_scenario::next_tx(scenario, user1);
    {
        let sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
        let eth = test_scenario::take_from_sender<Coin<ETH_COIN>>(scenario);

        debug::print(&b"Balances after Flash Loan".to_string());
        debug::print(&b"SUI:".to_string());
        debug::print(&sui.value());
        debug::print(&b"ETH:".to_string());
        debug::print(&eth.value());
        transfer::public_transfer(sui, user1);
        transfer::public_transfer(eth, user1);
    };

    test_scenario::end(scenario_val);
}