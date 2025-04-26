import "AutoBattler"

access(all) contract BattleBalls {

    init() {
        let passCap = self.account.capabilities.storage.issue<auth(AutoBattler.Pass) &{AutoBattler.Season}>(/storage/BattleBallsSeasonPass)
        let season: @AutoBattler.StandardSeason <- AutoBattler.createSeason(
            url: "",
            name: "Battleballs",
            currencyName: "Beads",
            currencySymbol: "BBB",
            currencyPerStorePhase: 10,
            RunPrice: 0.3,
            cap: passCap
        )

        season.addEntity(
            AutoBattler.veryBasicEntity(health: 1, damage: 1, metadata: AutoBattler.Metadata(name: "Beach", description: "A beach ball.", imageUrl: "")),
            price: 2
        )
        season.addEntity(
            AutoBattler.veryBasicEntity(health: 1, damage: 2, metadata: AutoBattler.Metadata(name: "Foot", description: "A football.", imageUrl: "")),
            price: 3
        )
        season.addEntity(
            AutoBattler.veryBasicEntity(health: 2, damage: 1, metadata: AutoBattler.Metadata(name: "Bouncy", description: "A bouncy ball.", imageUrl: "")),
            price: 3
        )
        season.addEntity(
            AutoBattler.veryBasicEntity(health: 2, damage: 2, metadata: AutoBattler.Metadata(name: "Tennis", description: "A tennis ball.", imageUrl: "")),
            price: 4
        )
        season.addEntity(
            AutoBattler.veryBasicEntity(health: 3, damage: 1, metadata: AutoBattler.Metadata(name: "Base", description: "A baseball.", imageUrl: "")),
            price: 4
        )
        season.addEntity(
            AutoBattler.veryBasicEntity(health: 1, damage: 3, metadata: AutoBattler.Metadata(name: "Medicine", description: "A medicine ball.", imageUrl: "")),
            price: 4
        )

        self.account.storage.save(<-season, to: /storage/BattleBallsSeason)
 
        let pubCap = self.account.capabilities.storage.issue<&{AutoBattler.Season}>(/storage/BattleBalls)
        self.account.capabilities.publish(pubCap, at: /public/BattleBallsSeason)
    }

}
