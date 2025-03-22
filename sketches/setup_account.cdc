import AutoGame from "AutoGame"

transaction {

    prepare(account: auth(IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {
        // Create a new RunCollection and store it in the account's storage
        let runCollection <- AutoGame.createEmptyRunCollection()
        account.storage.save(<-runCollection, to: AutoGame.RunCollectionStoragePath)
        let runCollectionCapability = account.capabilities.storage.issue<&AutoGame.RunCollection>(AutoGame.RunCollectionStoragePath)
        account.capabilities.publish(runCollectionCapability, at: AutoGame.RunCollectionPublicPath)
     
        // Create a new DomainCollection and store it in the account's storage
        let domainCollection <- AutoGame.createEmptyDomainCollection()
        account.storage.save(<-domainCollection, to: AutoGame.DomainCollectionStoragePath)
        let domainCollectionCapability = account.capabilities.storage.issue<&AutoGame.DomainCollection>(AutoGame.DomainCollectionStoragePath)
        account.capabilities.publish(domainCollectionCapability, at: AutoGame.DomainCollectionPublicPath)
      }

    execute {
        log("Account initialized with entity, run, and domain collections.")
    }
}