import AutoGame from "AutoGame"

access(all) fun main(account: Address): [{AutoGame.BattleState}] {
    // Borrow the RunCollection from the account's storage
    let account = getAccount(account)
    let runCollectionRef = account.capabilities
        .borrow<&AutoGame.RunCollection>(AutoGame.RunCollectionPublicPath)
        ?? panic("Could not borrow reference to the run collection")

    // Get the current run (assuming the last run is the current one)
    let runIDs = runCollectionRef.getIDs()
    if runIDs.length == 0 {
        return []
    }
    let currentRunID = runIDs[runIDs.length - 1]
    let currentRunRef = runCollectionRef.borrowRun(id: currentRunID)

    // Get the battle result from the current run
    let battleIndex = currentRunRef.battleCount() - 1
    let battle = currentRunRef.borrowBattle(index: battleIndex)

    return battle.replay()
}