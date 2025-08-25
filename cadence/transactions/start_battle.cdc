import "AutoBattler"

transaction(passPath: StoragePath) {
    let pass: &AutoBattler.Pass

    prepare(acct: auth(Storage) &Account) {
        self.pass = acct.storage.borrow<&AutoBattler.Pass>(from: passPath)!
    }

    execute {
        self.pass.startBattle()
    }
}