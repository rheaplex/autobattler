import "NonFungibleToken"
import "AutoGame"

access(all) fun main(address: Address): [UInt64] {
    let account = getAccount(address)

    let collectionRef = account.capabilities.borrow<&{NonFungibleToken.Collection}>(
            AutoGame.CardCollectionPublicPath
    ) ?? panic("The account ".concat(address.toString()).concat(" does not have a Card Collection at ")
                .concat(AutoGame.CardCollectionPublicPath.toString())
                .concat(". The account must initialize their account with this collection first!"))

    return collectionRef.getIDs()
}