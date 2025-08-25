import "FungibleToken"
import "FlowToken"

import "AutoBattler"

transaction(charactersAcct: Address) {
    let storage: auth(Storage, Capabilities) &Account.Storage
    let capabilities: auth(Capabilities) &Account.Capabilities
    let charactersCapabilities: &Account.Capabilities

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.storage = acct.storage
        self.capabilities = acct.capabilities
        self.charactersCapabilities = getAccount(charactersAcct).capabilities
    }

    execute {
        // Create vault to hold BattleBalls season payments
        let seasonVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        self.storage.save(<-seasonVault, to: /storage/BattleBallsSeasonVault)
        let seasonVaultCap = self.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/BattleBallsSeasonVault)

        // Create the season
        let delegate <- AutoBattler.createDefaultSeasonDelegate()
        // FIXME: see AutoBattler.cdc
        let seasonCap = self.capabilities.storage.issue<auth(AutoBattler.SeasonPass) &AutoBattler.Season>(/storage/BattleBallsSeason)
        let battleBalls <- AutoBattler.createSeason(
            url: "battleballs.game",
            name: "Battle Balls Season 1",
            delegate: <-delegate,
            currencyName: "Battle Points",
            currencySymbol: "BP",
            currencyPerStorePhase: 3,
            runPrice: 20.0,
            paymentVaultCap: seasonVaultCap,
            seasonPassCap: seasonCap
        )

        // Save the season to storage
        self.storage.save(<-battleBalls, to: /storage/BattleBallsSeason)

        // Make it so that anyone can buy a season pass
        let purchaseSeasonCap = self.capabilities.storage.issue<auth(AutoBattler.PurchaseSeasonPass) &AutoBattler.Season>(/storage/BattleBallsSeason)
        let vendor <- AutoBattler.createSeasonPassVendor(seasonPassCap: purchaseSeasonCap)
        self.storage.save(<-vendor, to: /storage/BattleBallsVendor)
        let vendorCap = self.capabilities.storage.issue<&AutoBattler.SeasonPassVendor>(/storage/BattleBallsVendor)
        self.capabilities.publish(vendorCap, at: /public/PurchaseBattleBallsPass)

        // Get a reference to the season for adding entities
        let season = self.storage.borrow<auth(AutoBattler.InstallCharacter) &AutoBattler.Season>(from: /storage/BattleBallsSeason)!

        // Install CharacterDefinition for each ball

        // Beachball
        let beachBall = self.charactersCapabilities.borrow<&AutoBattler.CharacterDefinitionInstaller>(/public/beachballinstaller)!
        let beachBallId = beachBall.characterId()
        beachBall.addToSeason(season: season)
        season.setCharacterDetails(
            entityID: beachBallId,
            availableAtLevel: 1,
            availableAfterBattles: 0,
            storePrice: 1
        )

        // Basketball
        let basketBall = self.charactersCapabilities.borrow<&AutoBattler.CharacterDefinitionInstaller>(/public/basketballinstaller)!
        let basketBallId = basketBall.characterId()
        basketBall.addToSeason(season: season)
        season.setCharacterDetails(
            entityID: basketBallId,
            availableAtLevel: 2,
            availableAfterBattles: 3,
            storePrice: 2
        )

        // Soccer Ball
        let soccerBall = self.charactersCapabilities.borrow<&AutoBattler.CharacterDefinitionInstaller>(/public/soccerballinstaller)!
        let soccerBallId = soccerBall.characterId()
        soccerBall.addToSeason(season: season)
        season.setCharacterDetails(
            entityID: soccerBallId,
            availableAtLevel: 3,
            availableAfterBattles: 5,
            storePrice: 3
        )

        // Bowling Ball
        let bowlingBall = self.charactersCapabilities.borrow<&AutoBattler.CharacterDefinitionInstaller>(/public/bowlingballinstaller)!
        let bowlingBallId = bowlingBall.characterId()
        bowlingBall.addToSeason(season: season)
        season.setCharacterDetails(
            entityID: bowlingBallId,
            availableAtLevel: 4,
            availableAfterBattles: 8,
            storePrice: 4
        )

        // Tennis Ball
        let tennisBall = self.charactersCapabilities.borrow<&AutoBattler.CharacterDefinitionInstaller>(/public/tennisballinstaller)!
        let tennisBallId = tennisBall.characterId()
        tennisBall.addToSeason(season: season)
        season.setCharacterDetails(
            entityID: tennisBallId,
            availableAtLevel: 2,
            availableAfterBattles: 2,
            storePrice: 2
        )
    }
}
