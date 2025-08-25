import "FungibleToken"
import "FlowToken"

import "AutoBattler"

transaction(autoBattlerAcct: Address) {
    let storage: auth(Storage, Capabilities) &Account.Storage
    let capabilities: auth(Capabilities) &Account.Capabilities
    let autobattler: &Account

    prepare(acct: auth(Storage, Capabilities, PublishCapability) &Account) {
        self.storage = acct.storage
        self.capabilities = acct.capabilities
        self.autobattler = getAccount(autoBattlerAcct)

        // Create vaults to hold payments
        let characterVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        acct.storage.save(<-characterVault, to: /storage/BattleBallsCharacterVault)
    }

    execute {
        // Create vault to hold BattleBalls character instantiation payments
        let characterVaultCap = self.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/BattleBallsCharacterVault)

        let damageSystem = self.autobattler.capabilities.get<&{AutoBattler.System}>(/public/battleSystem)
        let metadataSystem = self.autobattler.capabilities.get<&{AutoBattler.System}>(/public/metadataSystem)

        // Create CharacterDefinitions for each ball

        // Beachball
        let beachBallCap = self.capabilities.storage.issue<auth(AutoBattler.InstantiateCharacter) &AutoBattler.CharacterDefinition>(/storage/BeachBall)
        let beachBall <- AutoBattler.createCharacterDefinition(instantiatorCap: beachBallCap, vault: characterVaultCap)
        beachBall.addComponent(component: AutoBattler.Health(value: 1), systemCap: damageSystem)
        beachBall.addComponent(component: AutoBattler.Damage(amount: 1), systemCap:damageSystem)
        beachBall.addComponent(component: AutoBattler.Metadata(name: "Beach", description: "A beach ball.", imageUrl: ""),
                               systemCap: metadataSystem)
        beachBall.setPrice(2.0)
        self.storage.save(<-beachBall, to: /storage/BeachBall)
        // We don't have to do this. Doing so makes the character publicly installable without our assistance/control.
        let beachBallInstallCap = self.capabilities.storage.issue<auth(AutoBattler.InstallCharacter) &AutoBattler.CharacterDefinition>(/storage/BeachBall)
        let beachBallInstaller <- AutoBattler.createCharacterDefinitionInstaller(instantiatorCap: beachBallInstallCap)
        self.storage.save(<-beachBallInstaller, to: /storage/beachballinstaller)
        let beachBallPubCap = self.capabilities.storage.issue<&AutoBattler.CharacterDefinitionInstaller>(/storage/beachballinstaller)
        self.capabilities.publish(beachBallPubCap, at: /public/beachballinstaller)

        // Basketball
        let basketBallCap = self.capabilities.storage.issue<auth(AutoBattler.InstantiateCharacter) &AutoBattler.CharacterDefinition>(/storage/BasketBall)
        let basketBall <- AutoBattler.createCharacterDefinition(instantiatorCap: basketBallCap, vault: characterVaultCap)
        basketBall.addComponent(component: AutoBattler.Health(value: 2), systemCap: damageSystem)
        basketBall.addComponent(component: AutoBattler.Damage(amount: 2), systemCap: damageSystem)
        basketBall.addComponent(component: AutoBattler.Metadata(name: "Basketball", description: "A tough basketball with good bounce.", imageUrl: ""),
                               systemCap: metadataSystem)
        basketBall.setPrice(3.0)
        self.storage.save(<-basketBall, to: /storage/BasketBall)
        // We don't have to do this. Doing so makes the character publicly installable without our assistance/control.
        let basketBallInstallCap = self.capabilities.storage.issue<auth(AutoBattler.InstallCharacter) &AutoBattler.CharacterDefinition>(/storage/BasketBall)
        let basketBallInstaller <- AutoBattler.createCharacterDefinitionInstaller(instantiatorCap: basketBallInstallCap)
        self.storage.save(<-basketBallInstaller, to: /storage/basketballinstaller)
        let basketBallPubCap = self.capabilities.storage.issue<&AutoBattler.CharacterDefinitionInstaller>(/storage/basketballinstaller)
        self.capabilities.publish(basketBallPubCap, at: /public/basketballinstaller)

        // Soccer Ball
        let soccerBallCap = self.capabilities.storage.issue<auth(AutoBattler.InstantiateCharacter) &AutoBattler.CharacterDefinition>(/storage/SoccerBall)
        let soccerBall <- AutoBattler.createCharacterDefinition(instantiatorCap: soccerBallCap, vault: characterVaultCap)
        soccerBall.addComponent(component: AutoBattler.Health(value: 3), systemCap: damageSystem)
        soccerBall.addComponent(component: AutoBattler.Damage(amount: 1), systemCap: damageSystem)
        soccerBall.addComponent(component: AutoBattler.Metadata(name: "Soccer Ball", description: "A durable soccer ball with high endurance.", imageUrl: ""),
                               systemCap: metadataSystem)
        soccerBall.setPrice(4.0)
        self.storage.save(<-soccerBall, to: /storage/SoccerBall)
        // We don't have to do this. Doing so makes the character publicly installable without our assistance/control.
        let soccerBallInstallCap = self.capabilities.storage.issue<auth(AutoBattler.InstallCharacter) &AutoBattler.CharacterDefinition>(/storage/SoccerBall)
        let soccerBallInstaller <- AutoBattler.createCharacterDefinitionInstaller(instantiatorCap: soccerBallInstallCap)
        self.storage.save(<-soccerBallInstaller, to: /storage/soccerballinstaller)
        let soccerBallPubCap = self.capabilities.storage.issue<&AutoBattler.CharacterDefinitionInstaller>(/storage/soccerballinstaller)
        self.capabilities.publish(soccerBallPubCap, at: /public/soccerballinstaller)

        // Bowling Ball
        let bowlingBallCap = self.capabilities.storage.issue<auth(AutoBattler.InstantiateCharacter) &AutoBattler.CharacterDefinition>(/storage/BowlingBall)
        let bowlingBall <- AutoBattler.createCharacterDefinition(instantiatorCap: bowlingBallCap, vault: characterVaultCap)
        bowlingBall.addComponent(component: AutoBattler.Health(value: 1), systemCap: damageSystem)
        bowlingBall.addComponent(component: AutoBattler.Damage(amount: 4), systemCap: damageSystem)
        bowlingBall.addComponent(component: AutoBattler.Metadata(name: "Bowling Ball", description: "A heavy bowling ball that packs a punch.", imageUrl: ""),
                               systemCap: metadataSystem)
        bowlingBall.setPrice(5.0)
        self.storage.save(<-bowlingBall, to: /storage/BowlingBall)
        // We don't have to do this. Doing so makes the character publicly installable without our assistance/control.
        let bowlingBallInstallCap = self.capabilities.storage.issue<auth(AutoBattler.InstallCharacter) &AutoBattler.CharacterDefinition>(/storage/BowlingBall)
        let bowlingBallInstaller <- AutoBattler.createCharacterDefinitionInstaller(instantiatorCap: bowlingBallInstallCap)
        self.storage.save(<-bowlingBallInstaller, to: /storage/bowlingballinstaller)
        let bowlingBallPubCap = self.capabilities.storage.issue<&AutoBattler.CharacterDefinitionInstaller>(/storage/bowlingballinstaller)
        self.capabilities.publish(bowlingBallPubCap, at: /public/bowlingballinstaller)

        // Tennis Ball
        let tennisBallCap = self.capabilities.storage.issue<auth(AutoBattler.InstantiateCharacter) &AutoBattler.CharacterDefinition>(/storage/TennisBall)
        let tennisBall <- AutoBattler.createCharacterDefinition(instantiatorCap: tennisBallCap, vault: characterVaultCap)
        tennisBall.addComponent(component: AutoBattler.Health(value: 1), systemCap: damageSystem)
        tennisBall.addComponent(component: AutoBattler.Damage(amount: 3), systemCap: damageSystem)
        tennisBall.addComponent(component: AutoBattler.Metadata(name: "Tennis Ball", description: "A quick and nimble tennis ball.", imageUrl: ""),
                               systemCap: metadataSystem)
        tennisBall.setPrice(3.5)
        self.storage.save(<-tennisBall, to: /storage/TennisBall)
        // We don't have to do this. Doing so makes the character publicly installable without our assistance/control.
        let tennisBallInstallCap = self.capabilities.storage.issue<auth(AutoBattler.InstallCharacter) &AutoBattler.CharacterDefinition>(/storage/TennisBall)
        let tennisBallInstaller <- AutoBattler.createCharacterDefinitionInstaller(instantiatorCap: tennisBallInstallCap)
        self.storage.save(<-tennisBallInstaller, to: /storage/tennisballinstaller)
        let tennisBallPubCap = self.capabilities.storage.issue<&AutoBattler.CharacterDefinitionInstaller>(/storage/tennisballinstaller)
        self.capabilities.publish(tennisBallPubCap, at: /public/tennisballinstaller)
    }
}