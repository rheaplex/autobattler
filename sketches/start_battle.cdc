/*

import "NonFungibleToken"
import "AutoGame"

transaction(teamIDsBattleOwner: [UInt64], teamIDsOpponent: [UInt64]) {

    // Reference to the player's card collection
    let cardCollectionOwner: Capability<&AutoGame.CardCollection>
    let cardCollectionOpponent: Capability<&AutoGame.CardCollection>


    prepare(battleOwner: auth(BorrowValue, StorageCapabilities, SaveValue) &Account, opponent: auth(BorrowValue, StorageCapabilities) &Account) {
        // Make sure a battle is not already in progress
        if battleOwner.storage.borrow<&AutoGame.Battle>(from: AutoGame.BattleCurrentStoragePath) != nil {
            panic("The battle owner already has a battle in progress!")
        }

        // Get card collection capabilities
        self.cardCollectionOwner = battleOwner.capabilities.storage.issue<&AutoGame.CardCollection>(
            AutoGame.CardCollectionStoragePath
        )
        self.cardCollectionOpponent = opponent.capabilities.storage.issue<&AutoGame.CardCollection>(
            AutoGame.CardCollectionStoragePath
        )

        let battle<- AutoGame.createBattle(
            team1Cap: self.cardCollectionOwner,
            team2Cap: self.cardCollectionOpponent,
            team1IDs: teamIDsBattleOwner,
            team2IDs: teamIDsOpponent
        )

        // We can't do this in execute because we don't have access to storage there.
        battleOwner.storage.save(<-battle, to: AutoGame.BattleCurrentStoragePath)
    }
}

*/