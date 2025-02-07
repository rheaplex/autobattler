import AutoGame from "AutoGame"

access(all) fun main(account: Address): AutoGame.BattleResult? {
    // Borrow the RunCollection from the account's storage
    let account = getAccount(account)
    let runCollectionRef = account.capabilities
        .borrow<&AutoGame.RunCollection>(AutoGame.RunCollectionPublicPath)
        ?? panic("Could not borrow reference to the run collection")

    // Get the current run (assuming the last run is the current one)
    let runIDs = runCollectionRef.getIDs()
    if runIDs.length == 0 {
        return nil
    }
    let currentRunID = runIDs[runIDs.length - 1]
    let currentRunRef = runCollectionRef.borrowRun(id: currentRunID)

    // Get the battle result from the current run
    let battleIndex = currentRunRef.battles.length - 1
    let battle = currentRunRef.battles[battleIndex]
   
    return battle.result
}