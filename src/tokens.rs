//! Additional CEP-18 compatible token implementations for DEX testing
//! Each token is a separate type so Odra can deploy them independently
use odra::prelude::*;
use odra::casper_types::U256;
use crate::events::{Transfer, Approval};
use crate::errors::TokenError;

/// ECTO Token - Ectoplasm native token
#[odra::module]
pub struct EctoToken {
    name: Var<String>,
    symbol: Var<String>,
    decimals: Var<u8>,
    total_supply: Var<U256>,
    balances: Mapping<Address, U256>,
    allowances: Mapping<(Address, Address), U256>,
}

#[odra::module]
impl EctoToken {
    pub fn init(&mut self) {
        self.name.set(String::from("Ectoplasm Token"));
        self.symbol.set(String::from("ECTO"));
        self.decimals.set(18);
        self.total_supply.set(U256::zero());
    }

    pub fn name(&self) -> String { self.name.get_or_default() }
    pub fn symbol(&self) -> String { self.symbol.get_or_default() }
    pub fn decimals(&self) -> u8 { self.decimals.get_or_default() }
    pub fn total_supply(&self) -> U256 { self.total_supply.get_or_default() }
    pub fn balance_of(&self, owner: Address) -> U256 { self.balances.get(&owner).unwrap_or_default() }
    pub fn allowance(&self, owner: Address, spender: Address) -> U256 { self.allowances.get(&(owner, spender)).unwrap_or_default() }

    pub fn transfer(&mut self, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.transfer_internal(caller, to, amount);
        true
    }

    pub fn approve(&mut self, spender: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.approve_internal(caller, spender, amount);
        true
    }

    pub fn transfer_from(&mut self, from: Address, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        let current_allowance = self.allowance(from, caller);
        if current_allowance < amount { self.env().revert(TokenError::InsufficientAllowance); }
        self.approve_internal(from, caller, current_allowance - amount);
        self.transfer_internal(from, to, amount);
        true
    }

    pub fn mint(&mut self, to: Address, amount: U256) {
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply + amount);
        let current_balance = self.balance_of(to);
        self.balances.set(&to, current_balance + amount);
        self.env().emit_event(Transfer { from: Address::from(self.env().self_address()), to, value: amount });
    }

    pub fn burn(&mut self, from: Address, amount: U256) {
        let current_balance = self.balance_of(from);
        if current_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, current_balance - amount);
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply - amount);
        self.env().emit_event(Transfer { from, to: Address::from(self.env().self_address()), value: amount });
    }

    fn transfer_internal(&mut self, from: Address, to: Address, amount: U256) {
        let from_balance = self.balance_of(from);
        if from_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, from_balance - amount);
        let to_balance = self.balance_of(to);
        self.balances.set(&to, to_balance + amount);
        self.env().emit_event(Transfer { from, to, value: amount });
    }

    fn approve_internal(&mut self, owner: Address, spender: Address, amount: U256) {
        self.allowances.set(&(owner, spender), amount);
        self.env().emit_event(Approval { owner, spender, value: amount });
    }
}

/// USDC Token - USD Coin stablecoin (6 decimals)
#[odra::module]
pub struct UsdcToken {
    name: Var<String>,
    symbol: Var<String>,
    decimals: Var<u8>,
    total_supply: Var<U256>,
    balances: Mapping<Address, U256>,
    allowances: Mapping<(Address, Address), U256>,
}

#[odra::module]
impl UsdcToken {
    pub fn init(&mut self) {
        self.name.set(String::from("USD Coin"));
        self.symbol.set(String::from("USDC"));
        self.decimals.set(6);
        self.total_supply.set(U256::zero());
    }

    pub fn name(&self) -> String { self.name.get_or_default() }
    pub fn symbol(&self) -> String { self.symbol.get_or_default() }
    pub fn decimals(&self) -> u8 { self.decimals.get_or_default() }
    pub fn total_supply(&self) -> U256 { self.total_supply.get_or_default() }
    pub fn balance_of(&self, owner: Address) -> U256 { self.balances.get(&owner).unwrap_or_default() }
    pub fn allowance(&self, owner: Address, spender: Address) -> U256 { self.allowances.get(&(owner, spender)).unwrap_or_default() }

    pub fn transfer(&mut self, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.transfer_internal(caller, to, amount);
        true
    }

    pub fn approve(&mut self, spender: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.approve_internal(caller, spender, amount);
        true
    }

    pub fn transfer_from(&mut self, from: Address, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        let current_allowance = self.allowance(from, caller);
        if current_allowance < amount { self.env().revert(TokenError::InsufficientAllowance); }
        self.approve_internal(from, caller, current_allowance - amount);
        self.transfer_internal(from, to, amount);
        true
    }

    pub fn mint(&mut self, to: Address, amount: U256) {
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply + amount);
        let current_balance = self.balance_of(to);
        self.balances.set(&to, current_balance + amount);
        self.env().emit_event(Transfer { from: Address::from(self.env().self_address()), to, value: amount });
    }

    pub fn burn(&mut self, from: Address, amount: U256) {
        let current_balance = self.balance_of(from);
        if current_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, current_balance - amount);
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply - amount);
        self.env().emit_event(Transfer { from, to: Address::from(self.env().self_address()), value: amount });
    }

    fn transfer_internal(&mut self, from: Address, to: Address, amount: U256) {
        let from_balance = self.balance_of(from);
        if from_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, from_balance - amount);
        let to_balance = self.balance_of(to);
        self.balances.set(&to, to_balance + amount);
        self.env().emit_event(Transfer { from, to, value: amount });
    }

    fn approve_internal(&mut self, owner: Address, spender: Address, amount: U256) {
        self.allowances.set(&(owner, spender), amount);
        self.env().emit_event(Approval { owner, spender, value: amount });
    }
}

/// WETH Token - Wrapped Ether
#[odra::module]
pub struct WethToken {
    name: Var<String>,
    symbol: Var<String>,
    decimals: Var<u8>,
    total_supply: Var<U256>,
    balances: Mapping<Address, U256>,
    allowances: Mapping<(Address, Address), U256>,
}

#[odra::module]
impl WethToken {
    pub fn init(&mut self) {
        self.name.set(String::from("Wrapped Ether"));
        self.symbol.set(String::from("WETH"));
        self.decimals.set(18);
        self.total_supply.set(U256::zero());
    }

    pub fn name(&self) -> String { self.name.get_or_default() }
    pub fn symbol(&self) -> String { self.symbol.get_or_default() }
    pub fn decimals(&self) -> u8 { self.decimals.get_or_default() }
    pub fn total_supply(&self) -> U256 { self.total_supply.get_or_default() }
    pub fn balance_of(&self, owner: Address) -> U256 { self.balances.get(&owner).unwrap_or_default() }
    pub fn allowance(&self, owner: Address, spender: Address) -> U256 { self.allowances.get(&(owner, spender)).unwrap_or_default() }

    pub fn transfer(&mut self, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.transfer_internal(caller, to, amount);
        true
    }

    pub fn approve(&mut self, spender: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.approve_internal(caller, spender, amount);
        true
    }

    pub fn transfer_from(&mut self, from: Address, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        let current_allowance = self.allowance(from, caller);
        if current_allowance < amount { self.env().revert(TokenError::InsufficientAllowance); }
        self.approve_internal(from, caller, current_allowance - amount);
        self.transfer_internal(from, to, amount);
        true
    }

    pub fn mint(&mut self, to: Address, amount: U256) {
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply + amount);
        let current_balance = self.balance_of(to);
        self.balances.set(&to, current_balance + amount);
        self.env().emit_event(Transfer { from: Address::from(self.env().self_address()), to, value: amount });
    }

    pub fn burn(&mut self, from: Address, amount: U256) {
        let current_balance = self.balance_of(from);
        if current_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, current_balance - amount);
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply - amount);
        self.env().emit_event(Transfer { from, to: Address::from(self.env().self_address()), value: amount });
    }

    fn transfer_internal(&mut self, from: Address, to: Address, amount: U256) {
        let from_balance = self.balance_of(from);
        if from_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, from_balance - amount);
        let to_balance = self.balance_of(to);
        self.balances.set(&to, to_balance + amount);
        self.env().emit_event(Transfer { from, to, value: amount });
    }

    fn approve_internal(&mut self, owner: Address, spender: Address, amount: U256) {
        self.allowances.set(&(owner, spender), amount);
        self.env().emit_event(Approval { owner, spender, value: amount });
    }
}

/// WBTC Token - Wrapped Bitcoin (8 decimals)
#[odra::module]
pub struct WbtcToken {
    name: Var<String>,
    symbol: Var<String>,
    decimals: Var<u8>,
    total_supply: Var<U256>,
    balances: Mapping<Address, U256>,
    allowances: Mapping<(Address, Address), U256>,
}

#[odra::module]
impl WbtcToken {
    pub fn init(&mut self) {
        self.name.set(String::from("Wrapped Bitcoin"));
        self.symbol.set(String::from("WBTC"));
        self.decimals.set(8);
        self.total_supply.set(U256::zero());
    }

    pub fn name(&self) -> String { self.name.get_or_default() }
    pub fn symbol(&self) -> String { self.symbol.get_or_default() }
    pub fn decimals(&self) -> u8 { self.decimals.get_or_default() }
    pub fn total_supply(&self) -> U256 { self.total_supply.get_or_default() }
    pub fn balance_of(&self, owner: Address) -> U256 { self.balances.get(&owner).unwrap_or_default() }
    pub fn allowance(&self, owner: Address, spender: Address) -> U256 { self.allowances.get(&(owner, spender)).unwrap_or_default() }

    pub fn transfer(&mut self, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.transfer_internal(caller, to, amount);
        true
    }

    pub fn approve(&mut self, spender: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        self.approve_internal(caller, spender, amount);
        true
    }

    pub fn transfer_from(&mut self, from: Address, to: Address, amount: U256) -> bool {
        let caller = self.env().caller();
        let current_allowance = self.allowance(from, caller);
        if current_allowance < amount { self.env().revert(TokenError::InsufficientAllowance); }
        self.approve_internal(from, caller, current_allowance - amount);
        self.transfer_internal(from, to, amount);
        true
    }

    pub fn mint(&mut self, to: Address, amount: U256) {
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply + amount);
        let current_balance = self.balance_of(to);
        self.balances.set(&to, current_balance + amount);
        self.env().emit_event(Transfer { from: Address::from(self.env().self_address()), to, value: amount });
    }

    pub fn burn(&mut self, from: Address, amount: U256) {
        let current_balance = self.balance_of(from);
        if current_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, current_balance - amount);
        let current_supply = self.total_supply();
        self.total_supply.set(current_supply - amount);
        self.env().emit_event(Transfer { from, to: Address::from(self.env().self_address()), value: amount });
    }

    fn transfer_internal(&mut self, from: Address, to: Address, amount: U256) {
        let from_balance = self.balance_of(from);
        if from_balance < amount { self.env().revert(TokenError::InsufficientBalance); }
        self.balances.set(&from, from_balance - amount);
        let to_balance = self.balance_of(to);
        self.balances.set(&to, to_balance + amount);
        self.env().emit_event(Transfer { from, to, value: amount });
    }

    fn approve_internal(&mut self, owner: Address, spender: Address, amount: U256) {
        self.allowances.set(&(owner, spender), amount);
        self.env().emit_event(Approval { owner, spender, value: amount });
    }
}