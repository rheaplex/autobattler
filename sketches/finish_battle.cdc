import AutoGame from "AutoGame"

transaction {

    prepare(account: auth(BorrowValue) &Account) {
        // Borrow the RunCollection from the account's storage
        let runCollectionRef = account.storage.borrow<&AutoGame.RunCollection>(from: AutoGame.RunCollectionStoragePath)
            ?? panic("Could not borrow reference to the run collection")

        // Get the current run (assuming the last run is the current one)
        let runIDs = runCollectionRef.getIDs()
        if runIDs.length == 0 {
            panic("No runs available to resolve a battle")
        }
        let currentRunID = runIDs[runIDs.length - 1]
        let currentRunRef = runCollectionRef.borrowRun(id: currentRunID)

        // Get the current battle (assuming the last battle is the current one)
        let battleIndex = currentRunRef.battleCount() - 1
        let currentBattleRef = currentRunRef.borrowBattle(index: battleIndex)

        // Resolve the battle
        currentBattleRef.resolve()
    }
}