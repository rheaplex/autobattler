import AutoBattler from "AutoBattler"



access(all) fun main(account: Address): [String] {
    // Borrow the RunCollection from the account's storage
    let account = getAccount(account)
    let battle = account.capabilities.borrow<&AutoBattler.Battle>(/public/battle)
        ?? panic("Could not borrow reference to the Battle")

    let turns: [AutoBattler.Turn] = battle.simulate()
    let descs: [String] = ["Result: ".concat(battle.result.rawValue.toString())]

    for i in InclusiveRange(0, turns.length - 1) {
        descs.append(i.toString().concat(" - ").concat(turns[i].toString()))
    }

    return descs
}