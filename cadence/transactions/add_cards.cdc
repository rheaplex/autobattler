import "NonFungibleToken"
import "MetadataViews"
import "FungibleToken"

import "AutoGame"

transaction(
    recipient: Address,
    amount: UInt8
) {

    /// local variable for storing the minter reference
    let minter: &AutoGame.CardMinter

    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) { 
        // borrow a reference to the NFTMinter resource in storage
        self.minter = AutoGame.minter

      // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(recipient).capabilities.borrow<&{NonFungibleToken.Receiver}>(AutoGame.CardCollectionPublicPath)
            ?? panic("The recipient does not have a NonFungibleToken Receiver at "
                    .concat(AutoGame.CardCollectionPublicPath.toString())
                    .concat(" that is capable of receiving an NFT.")
                    .concat("The recipient must initialize their account with this collection and receiver first!"))

    }

    execute {
        // Create the cards
        var count: UInt8 = 0
        var level: UInt8 = 0
        while count < amount {
            var attack: UInt32 = 1 + revertibleRandom<UInt32>(modulo:4)
            var health: UInt32 = 2 + revertibleRandom<UInt32>(modulo:6)
            let mintedNFT<-  self.minter.mintCard(
                name: "Card ".concat(count.toString()),
                url: "ipfs://blah/".concat(count.toString()),
                attack: attack,
                health: health,
                level: level
            )
            count = count + 1
            self.recipientCollectionRef.deposit(token: <-mintedNFT)
        }
    }

}