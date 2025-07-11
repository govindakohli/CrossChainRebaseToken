# Cross-chain Rebase Token

1. A protocol that allows user to deposit into a vault and in return, receive rebase tokens represent their underlying balance
2. Rebase token -> balanceOf function is dynamic to show the changing balance with time.
    - Balance increases linearly with time
    - mint tokens to our users every time they perform an action (minting , burning , transferring, or.. bridging)
3. Intrest rate 
    - Indivually set an intrest rate or each user based on some global intrest rate of protocol at the time the user deposit into the vault.
    - This global intrest rate can only decrease to incetivise/reward early adopters.
    - Increase token adoption!