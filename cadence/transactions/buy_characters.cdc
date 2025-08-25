import "AutoBattler"

transaction(passPath: StoragePath, ids: [UInt64]) {
    let pass: &AutoBattler.Pass

    prepare(acct: auth(Storage) &Account) {
        self.pass = acct.storage.borrow<&AutoBattler.Pass>(from: passPath)!
    }

    execute {
        for id in ids {
            self.pass.buyCharacter(id: id)
        }
    }
}