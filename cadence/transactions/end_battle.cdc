import "AutoBattler"

access(all) fun resultToEn(_ result: UInt8): String {
    switch result {
        case 0: return "Undecided"
        case 1: return "Win"
        case 2: return "Lose"
        case 3: return "Draw"
        default: return "Unknown???"
    }
}

access(all) fun turnIndexToEn(_ turn: Int): String {
    if (turn == 0) {
        return "Before Play"
    } else {
        return "Turn \(turn)"
    }
}

transaction(passPath: StoragePath, battleIndex: UInt64) {
    let pass: &AutoBattler.Pass

    prepare(acct: auth(Storage) &Account) {
        self.pass = acct.storage.borrow<&AutoBattler.Pass>(from: passPath)!
    }

    execute {
        let result = self.pass.endBattle()
        log("Result: \(resultToEn(result.rawValue))")
        let turns = self.pass.simulateBattle(index: battleIndex)
        for index, turn in turns {
            log("\(turnIndexToEn(index)): \(turn.toString())")
        }
    }
}
