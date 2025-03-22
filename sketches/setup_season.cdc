import AutoGame from "AutoGame"

transaction(name: String, url: String, runPrice: UFix64) {

    prepare(account: auth(IssueStorageCapabilityController, BorrowValue, SaveValue) &Account) {
        let domainCollectionRef = account.storage.borrow<&AutoGame.DomainCollection>(from: AutoGame.DomainCollectionStoragePath)
            ?? panic("Could not borrow reference to the domain collection")

        // Create a StandardDomain
        let domain <- AutoGame.createStandardDomain(name: name, url: url, runPrice: runPrice)

        // Add the domain to the domain collection
        domainCollectionRef.deposit(domain: <-domain)
    }
}
