import "AutoGame"

transaction {
    prepare(battleOwner: auth(LoadValue) &Account) {
        let battle <- battleOwner.storage.load<@AutoGame.Battle>(from: AutoGame.BattleCurrentStoragePath)
            ?? panic("No battle found to end!")
        
        destroy battle
    }

    execute {
        // Nothing to do here - the battle is already cleaned up
    }
}
