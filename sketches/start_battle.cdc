import AutoGame from "AutoGame"

transaction() {

    prepare(account: auth(BorrowValue, Insert) &Account) {
        // Borrow the RunCollection from the account's storage
        let runCollectionRef = account.capabilities.borrow<&AutoGame.RunCollection>(AutoGame.RunCollectionPublicPath)
            ?? panic("Could not borrow reference to the run collection")

        // Get the current run (assuming the last run is the current one)
        let runIDs = runCollectionRef.getIDs()
        if runIDs.length == 0 {
            panic("No runs available to start a battle")
        }
        let currentRunID = runIDs[runIDs.length - 1]
        let currentRunRef = runCollectionRef.borrowRun(id: currentRunID)

        // Start a new battle in the current run
        let battleID = currentRunRef.createBattle()
        let battleIndex = currentRunRef.battleCount() - 1
        let battle = currentRunRef.borrowBattle(index: battleIndex)
        assert(battle.id == battleID)
        battle.start()
    }

}