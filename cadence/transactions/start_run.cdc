import AutoGame from "AutoGame"
import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"

transaction(domainAddress: Address) {

    prepare(account: auth(BorrowValue) &Account) {
        let domainAccount = getAccount(domainAddress)
        // Borrow the DomainCollection from the account's storage
        let domainCollectionCap = domainAccount.capabilities.get<&AutoGame.DomainCollection>(
            AutoGame.DomainCollectionPublicPath
        )
        let domainCollectionRef = domainCollectionCap.borrow()
            ?? panic("Could not borrow reference to the domain collection")

        // Get the IDs of the domains
        let domainIDs = domainCollectionRef.getIDs()
        if domainIDs.length == 0 {
            panic("No domains available to start a run")
        }

        // Assuming the last domain is the one we want to start a run in
        let currentDomainID = domainIDs[domainIDs.length - 1]
        let currentDomainRef: &{AutoGame.Domain} = domainCollectionRef.borrowDomain(id: currentDomainID)

        // Get the price of the run
        let amount = currentDomainRef.getRunPrice()

        // Get a reference to the signer's stored vault
        let vaultRef = account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(from: /storage/flowTokenVault)
            ?? panic("The signer does not store a FlowToken.Provider object")

        let paymentVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        // Start a new run in the current domain
        let newRun <- currentDomainRef.start(payment: <-paymentVault, domainCollection: domainCollectionCap)
        
        // Add the new run to the run collection
        let runCollectionRef = account.capabilities.borrow<&AutoGame.RunCollection>(AutoGame.RunCollectionPublicPath)
            ?? panic("Could not borrow reference to the run collection")
        runCollectionRef.deposit(run: <-newRun)
    }

    execute {
        log("A new run has been started in the current domain.")
    }
}