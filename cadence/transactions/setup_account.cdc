import "NonFungibleToken"
import "AutoGame"

transaction {

    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        // Return early if the account already has a collection
        if signer.storage.borrow<&AutoGame.CardCollection>(from: AutoGame.CardCollectionStoragePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- AutoGame.createEmptyCollection(nftType: Type<@AutoGame.Card>())

        // save it to the account
        signer.storage.save(<-collection, to: AutoGame.CardCollectionStoragePath)

        // create a public capability for the collection
        let collectionCap = signer.capabilities.storage.issue<&AutoGame.CardCollection>(AutoGame.CardCollectionStoragePath)
        signer.capabilities.publish(collectionCap, at: AutoGame.CardCollectionPublicPath)
    }
}