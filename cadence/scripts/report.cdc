import AutoGame from "AutoGame"

access(all) fun battleStateToString(_ state: &{AutoGame.BattleState}): String {
    return "Mine: ["
    .concat(
        String.join(
            state.myTeam.map<String>(fun (id: UInt64): String { return id.toString() }),
            separator: ", "
        )
    )
    .concat("] ")
    .concat(state.myGold.toString())
    .concat(" ")
    .concat(state.myHearts.toString())
    .concat(" ")
    .concat(state.myRibbons.toString())
    .concat(", Theirs: [")
    .concat(
        String.join(
            state.theirTeam.map<String>(fun (id: UInt64): String { return id.toString() }),
            separator: ", "
        )
    )
    .concat("] ")
    .concat(state.theirGold.toString())
    .concat(" ")
    .concat(state.theirHearts.toString())
    .concat(" ")
    .concat(state.theirRibbons.toString())
    //.concat(" ")
    //.concat(state.entityStates.toString())
}

access(all) fun battleToStr(_ battle: &{AutoGame.Battle}): String {
    return battle.domainId.toString().concat(": ")
    .concat("  Progress: ")
    .concat(battle.progress.rawValue.toString())
    .concat("  Result: ")
    .concat(battle.result.rawValue.toString())
    .concat("  ")
    .concat(battleStateToString(battle.initialState))
}

access(all) fun runToStr(_ run: &{AutoGame.Run}): String {
    var str = run.id.toString().concat(": ")
    .concat(run.domainId.toString())
    .concat(" Battles (")
    for i in InclusiveRange(0, run.battles.length - 1) {
        let battle = run.borrowBattle(index: i)
        str = str.concat(battleToStr(battle)).concat(", ")
    }
    return str.concat(") ")
}

access(all)fun main(address: Address): [String] {
    let account = getAccount(address)
    var info : [String] = ["Address: ".concat(address.toString()).concat(":")]

    if let domainCollectionRef = account.capabilities
        .borrow<&AutoGame.DomainCollection>(AutoGame.DomainCollectionPublicPath) {
        let domainIDs = domainCollectionRef.getIDs()
        var domains = "Domain IDs: ".concat(
            String.join(
                domainIDs.map<String>(fun (id: UInt64): String { return id.toString() }),
                separator: ", "
            )
        )
        domains = domains.concat(".")
        info.append(domains)

    } else {
        info.append("No domain collection available.")
    }

    if let runCollectionRef = account.capabilities
        .borrow<&AutoGame.RunCollection>(AutoGame.RunCollectionPublicPath) {
        let runIDs = runCollectionRef.getIDs()
        var runs = "Runs: ".concat(
            String.join(
                runIDs.map<String>(
                    fun (id: UInt64): String {
                         return runToStr(
                            runCollectionRef.borrowRun(id: id))
                    }),
                separator: ", "
            )
        )
        runs = runs.concat(".")
        info.append(runs)
    } else {
        info.append("No run collection available.")
    }

    return info
}