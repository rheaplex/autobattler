import "FungibleToken"
import "FlowToken"

import "AutoBattler"

transaction(seasonAddress: Address, vendorPath: PublicPath, savePassPath: StoragePath) {
    let vendor: &AutoBattler.SeasonPassVendor
    var payment: @FlowToken.Vault
    let storage: auth(Storage) &Account.Storage


    prepare(acct: auth(Storage) &Account) {
        let vendorAcct = getAccount(seasonAddress)
        self.vendor = vendorAcct.capabilities.borrow<&AutoBattler.SeasonPassVendor>(vendorPath)!
        let amount: UFix64 = self.vendor.seasonPassCost()

        let vaultRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("The signer does not store a FlowToken Vault object at the path "
                    .concat("/storage/flowTokenVault. ")
                    .concat("The signer must initialize their account with this vault first!"))


        // Withdraw tokens from the signer's stored vault
        self.payment <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault

        self.storage = acct.storage
    }

    execute {
        var pass <- self.vendor.purchaseSeasonPass(payment: <-self.payment)
        self.storage.save<@AutoBattler.Pass>(<-pass, to: savePassPath)
    }
}