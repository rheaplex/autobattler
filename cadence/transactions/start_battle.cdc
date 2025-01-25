import "NonFungibleToken"
import "AutoGame"

access(all) fun collectionContainsCards(collectionIDs: [UInt64], ids: [UInt64]): Bool {
    let matchCardID = fun(id: UInt64): Bool {
        return collectionIDs.contains(id)
    }
    return ids.map(matchCardID).contains(false)
}

transaction(teamIDsBattleOwner: [UInt64], teamIDsOpponent: [UInt64]) {

    // Reference to the player's card collection
    let cardCollectionOwner: Capability<&AutoGame.CardCollection>
    let cardCollectionOpponent: Capability<&AutoGame.CardCollection>
    // Whether we can access all cards in the collections
    let cardsOKBattleOwner: Bool
    let cardsOKOpponent: Bool

    prepare(battleOwner: auth(BorrowValue, StorageCapabilities, SaveValue) &Account, opponent: auth(BorrowValue, StorageCapabilities) &Account) {
        // Make sure a battle is not already in progress
        if battleOwner.storage.borrow<&AutoGame.Battle>(from: AutoGame.BattleCurrentStoragePath) != nil {
            panic("The battle owner already has a battle in progress!")
        }

        // Get a reference to the signer's card collection
        self.cardCollectionOwner = battleOwner.capabilities.storage.issue<&AutoGame.CardCollection>(
            AutoGame.CardCollectionStoragePath
        )
        
        self.cardCollectionOpponent = opponent.capabilities.storage.issue<&AutoGame.CardCollection>(
            AutoGame.CardCollectionStoragePath
        )
        // Make sure that we can borrow via the capabilities, and that the players have the cards
        // in their collections

        self.cardsOKBattleOwner = collectionContainsCards(
            collectionIDs: self.cardCollectionOwner.borrow()!.getIDs(),
            ids: teamIDsBattleOwner
            )
        
        self.cardsOKOpponent = collectionContainsCards(
            collectionIDs: self.cardCollectionOpponent.borrow()!.getIDs(),
            ids: teamIDsOpponent
        )

        let battle<- AutoGame.createBattle(
            team1Cap: self.cardCollectionOwner,
            team2Cap: self.cardCollectionOpponent,
            team1IDs: teamIDsBattleOwner,
            team2IDs: teamIDsOpponent
        )

        battleOwner.storage.save(<-battle, to: AutoGame.BattleCurrentStoragePath)
    }

    // Roll back the state updates from prepare if anything was invalid
    pre {
        teamIDsBattleOwner.length == teamIDsOpponent.length
        : "Both players must use the same number of cards!"

        self.cardsOKBattleOwner
        : "Could not borrow all of battle owner's cards"

        self.cardsOKOpponent
        : "Could not borrow all of opponent's cards"

    }

    execute {
        // Create the battle using the contract's createBattle function

    }   
}