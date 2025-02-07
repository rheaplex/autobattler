import "AutoGame"

transaction() {

    let battleRef: &AutoGame.Battle

    prepare(battleOwner: auth(BorrowValue) &Account, opponent: auth(BorrowValue) &Account) {
        // Borrow the Battle resource from the owner's storage
        self.battleRef = battleOwner.storage
            .borrow<&AutoGame.Battle>(from: AutoGame.BattleCurrentStoragePath)
            ?? panic("Could not borrow Battle resource")
    }

    execute {
        self.battleRef.advanceTurn()
    }
}
