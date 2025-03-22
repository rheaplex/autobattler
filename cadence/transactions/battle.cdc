import AutoBattler from "AutoBattler"

transaction {
    
    prepare(account: auth(Storage, Capabilities) &Account) {
        let battle = AutoBattler.runOneBattle()
        // Remove the existing battle, as this is a very simple test.
        if account.storage.check<AutoBattler.Battle>(from: /storage/battle) {
            account.storage.load<AutoBattler.Battle>(from: /storage/battle)
            account.capabilities.unpublish(/public/battle)
        }
        account.storage.save(battle, to: /storage/battle)
        let cap = account.capabilities.storage.issue<&AutoBattler.Battle>(/storage/battle)
        account.capabilities.publish(cap, at: /public/battle)
        log(battle.simulate())
    }
}