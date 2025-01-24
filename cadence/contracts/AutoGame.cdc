import "MetadataViews"
import "ViewResolver"
import "NonFungibleToken"


access(all) contract AutoGame {


    ///////////////////////////////////////////////////////////////////
    // Contract Events
    ///////////////////////////////////////////////////////////////////

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)


    ///////////////////////////////////////////////////////////////////
    // NFT Collection storage paths
    ///////////////////////////////////////////////////////////////////

    access(all) let CharacterStoragePath: StoragePath
    access(all) let CharacterPublicPath: PublicPath
    access(all) let RosterStoragePath: StoragePath
    access(all) let RosterPublicPath: PublicPath


    ///////////////////////////////////////////////////////////////////
    // Contract variables
    ///////////////////////////////////////////////////////////////////

    access(all) var totalCharacterSupply: UInt64
    access(all) var totalRosterSupply: UInt64


    ///////////////////////////////////////////////////////////////////
    // Math Functions
    ///////////////////////////////////////////////////////////////////

    // Naive, slow, buggy.
    access(all) fun pow(_ n: Fix64, _ x: Fix64): Fix64 {
        var power: Fix64 = 0.0
        var count: Fix64 = 0.0
        while count < x {
            power = power * n
            count = count + 1.0
        }
        return power
    }

    access(all) fun min(_ a: Fix64, _ b: Fix64): Fix64 {
        return a < b ? a : b
    }

    access(all) fun minInt(_ a: Int, _ b: Int): Int {
        return a < b ? a : b
    }

    access(all) fun max(_ a: Fix64, _ b: Fix64): Fix64 {
        return a > b ? a : b
    }

    access(all) fun maxUInt8(_ a: UInt8, _ b: UInt8): UInt8 {
        return a > b ? a : b
    }


    ///////////////////////////////////////////////////////////////////
    // Character Template containing the base stats and metadata
    // TODO: should this be an NFT to allow treating it as property
    //       and trading it on marketplaces?
    ///////////////////////////////////////////////////////////////////

    // Character template 
    access(all) struct CharacterTemplate {
        access(all) let characterType: String
        access(all) let metadataURL: String
        access(all) let baseHealth: UInt8
        access(all) let baseAttack: UInt8
        access(all) let baseDefend: UInt8

        init(characterType: String, metadataURL: String, health: UInt8, attack: UInt8, defend: UInt8) {
            self.characterType = characterType
            self.metadataURL = metadataURL
            self.baseHealth = health
            self.baseAttack = attack
            self.baseDefend = defend
        }
    }


    ///////////////////////////////////////////////////////////////////
    // Dictionary to store character templates
    // FIXME: this shouldn't be centralized.
    ///////////////////////////////////////////////////////////////////

    access(all) let characterTemplates: {String: CharacterTemplate}


    ///////////////////////////////////////////////////////////////////
    // Create a new character template
    // FIXME: this should be a tx.
    ///////////////////////////////////////////////////////////////////

    access(all) fun createCharacterTemplate(
        characterType: String,
        metadataURL: String,
        health: UInt8,
        attack: UInt8,
        defend: UInt8
    ): CharacterTemplate {
        let template = CharacterTemplate(
            characterType: characterType,
            metadataURL: metadataURL,
            health: health,
            attack: attack,
            defend: defend
        )
        self.characterTemplates[characterType] = template
        return template
    }


    ///////////////////////////////////////////////////////////////////
    // Create empty NFT collection
    // We have multiple types of NFTs, so this handles that.
    ///////////////////////////////////////////////////////////////////

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        if nftType == Type<@Roster>() {
            return <- create RosterCollection()
        } else {
            return <- create CharacterInstanceCollection()
        }
    }

    ///////////////////////////////////////////////////////////////////
    // Character instance NFT resource
    ///////////////////////////////////////////////////////////////////

    access(all) resource CharacterInstance: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let template: CharacterTemplate
        access(all) var health: UInt8
        access(all) var attack: UInt8
        access(all) var defend: UInt8

        init(template: CharacterTemplate) {
            self.id = self.uuid
            self.template = template
            self.health = template.baseHealth
            self.attack = template.baseAttack
            self.defend = template.baseDefend
        }

        /// @{NonFungibleToken.Collection}
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <-AutoGame.createEmptyCollection(nftType: Type<@CharacterInstance>())
        }

        // Implement MetadataViews.Resolver
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.template.characterType,
                        description: "AutoGame Character",
                        thumbnail: MetadataViews.HTTPFile(url: self.template.metadataURL)
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits([
                        MetadataViews.Trait(name:"health", value: self.health, displayType: "Number", rarity: nil  ),
                        MetadataViews.Trait(name:"attack", value: self.attack, displayType: "Number", rarity: nil  ),
                        MetadataViews.Trait(name:"defend", value: self.defend, displayType: "Number", rarity: nil  )
                    ])
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: AutoGame.CharacterStoragePath,
                        publicPath: AutoGame.CharacterPublicPath,
                        publicCollection: Type<&AutoGame.CharacterInstanceCollection>(),
                        publicLinkedType: Type<&AutoGame.CharacterInstanceCollection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-AutoGame.createEmptyCollection(nftType: Type<@CharacterInstance>())
                        })
                    )
            }
            return nil
        }

        // Modify current stats
        access(all) fun modifyHealth(by amount: Int8) {
            let newHealth = Int8(self.health) + amount
            self.health = newHealth <= 0 ? 0 : UInt8(newHealth)
        }

        access(all) fun modifyAttack(by amount: Int8) {
            let newAttack = Int8(self.attack) + amount
            self.attack = newAttack <= 0 ? 0 : UInt8(newAttack)
        }

        access(all) fun modifyDefend(by amount: Int8) {
            let newDefend = Int8(self.defend) + amount
            self.defend = newDefend <= 0 ? 0 : UInt8(newDefend)
        }

        // Calculate damage based on attack and defender's defense
        access(all) fun calculateDamage(defender: &CharacterInstance): UInt8 {
            if self.attack <= defender.defend {
                return 1 // Minimum damage
            }
            return self.attack - defender.defend
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    // Create a new character from a template
    // TODO: this should be a tx, and allow payment for the template.
    /////////////////////////////////////////////////////////////////////////////////////////////////

    access(all) fun createCharacter(fromTemplate characterType: String): @CharacterInstance? {
        if let template = self.characterTemplates[characterType] {
            return <-create CharacterInstance(template: template)
        }
        return nil
    }


    ///////////////////////////////////////////////////////////////////
    // Character Instance Collection resource
    ///////////////////////////////////////////////////////////////////

    access(all) resource CharacterInstanceCollection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init () {
            self.ownedNFTs <- {}
        }

                /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@CharacterInstance>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@CharacterInstance>()
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("CharacterInstanceCollection.withdraw: Could not withdraw an NFT with ID "
                        .concat(withdrawID.toString())
                        .concat(". Check the submitted ID to make sure it is one that this collection owns."))

            return <-token
        }

        /// deposit takes a NFT and adds it to the collections dictionary
        /// and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token  <- token as! @CharacterInstance
            let id = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[token.id] <- token

            destroy oldToken
        }

        // NonFungibleToken.CollectionPublic
        access(all) view fun viewgetIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        access(all) fun borrowCharacter(at index: UInt64): &CharacterInstance? {
            if let nft: &{NonFungibleToken.NFT} = &self.ownedNFTs[index] {
                return nft as? &CharacterInstance
            } else {
                return nil
            }
        }

        // Create empty Character collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- AutoGame.createEmptyCollection(nftType: Type<@CharacterInstance>())
        }
    }

    ///////////////////////////////////////////////////////////////////
    // Roster resource: holds character instances for battles, tradable.
    // *NOT* a collection!
    ///////////////////////////////////////////////////////////////////

    access(all) resource Roster: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) var characters: @[CharacterInstance]
        access(all) let maxSize: Int

        init() {
            self.id = self.uuid
            self.characters <- []
            self.maxSize = 10
        }

        // Implement MetadataViews.Resolver
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>()
            ]
        }

        access(all) view fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "AutoGame Roster",
                        description: "A collection of characters",
                        thumbnail: MetadataViews.HTTPFile(url: "https://example.com/roster-thumbnail")
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits([
                        MetadataViews.Trait(name:"characters", value: self.characters.length, displayType: "Number", rarity: nil  ),
                        MetadataViews.Trait(name:"maxSize", value: self.maxSize, displayType: "Number", rarity: nil  )
                    ])
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: AutoGame.RosterStoragePath,
                        publicPath: AutoGame.RosterPublicPath,
                        publicCollection: Type<&AutoGame.RosterCollection>(),
                        publicLinkedType: Type<&AutoGame.RosterCollection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-AutoGame.createEmptyCollection(nftType: Type<@Roster>())
                        })
                    )
            }
            return nil
        }

        access(self) fun withdrawCharacterAt(index: Int): @CharacterInstance? {
            let len = self.characters.length
            if len == 0 || index < 0 || index >= len {
                return nil
            }
            // This should succeed given the above checks
            return <-self.characters.remove(at: index)
        }

        access(all) fun pushCharacter(_ character: @CharacterInstance) {
        pre {
                self.characters.length < self.maxSize: "Roster is full. Maximum size is ".concat(self.maxSize.toString())
            }
            self.characters.append(<-character)
        }
        
        access(all) fun popCharacter(): @CharacterInstance? {
            if self.characters.length == 0 {
                return nil
            }
            // This should succeed given the above checks
            return <-self.characters.removeLast()
        }

        access(all) fun depositCharacterAt(_ character: @CharacterInstance, index: Int) {
        pre {
                self.characters.length < self.maxSize: "Roster is full. Maximum size is ".concat(self.maxSize.toString())
            }
            self.characters.insert(at: index, <-character)
        }

        access(all) view fun borrowCharacterAt(_ index: Int): &CharacterInstance {
        pre {
                index >= 0 && index < self.characters.length: "Invalid Roster index: ".concat(index.toString())
            }
            return &self.characters[index]
        }

        /// getIDs returns an array of the IDs that are in the collection
        access(all) fun getIDs(): [UInt64] {
            let ids : [UInt64] = []
            for i in InclusiveRange<Int>(0, self.characters.length - 1) {
                ids.append(self.characters[i].id)
            }
            return ids
        }

        // Get the number of characters in the roster
        access(all) view fun getLength(): Int {
            return self.characters.length
        }

        // Check if roster is full
        access(all) view fun isFull(): Bool {
            return self.characters.length >= self.maxSize
        }

        // Get the average stats of all characters in the roster
        access(all) view fun getAverageStats(): {String: UInt8} {
            if self.characters.length == 0 {
                return {
                    "health": 0,
                    "attack": 0,
                    "defend": 0
                }
            }

            var totalHealth: UInt64 = 0
            var totalAttack: UInt64 = 0
            var totalDefend: UInt64 = 0

            var i = 0
            while i < self.characters.length {
                let char = &self.characters[i] as &CharacterInstance
                totalHealth = totalHealth + UInt64(char.health)
                totalAttack = totalAttack + UInt64(char.attack)
                totalDefend = totalDefend + UInt64(char.defend)
                i = i + 1
            }

            return {
                "health": UInt8(totalHealth / UInt64(self.characters.length)),
                "attack": UInt8(totalAttack / UInt64(self.characters.length)),
                "defend": UInt8(totalDefend / UInt64(self.characters.length))
            }
        }

        // Get the highest stat values in the roster
        access(all) fun getHighestStats(): {String: UInt8} {
            if self.characters.length == 0 {
                return {
                    "health": 0,
                    "attack": 0,
                    "defend": 0
                }
            }

            var maxHealth: UInt8 = 0
            var maxAttack: UInt8 = 0
            var maxDefend: UInt8 = 0

            var i = 0
            while i < self.characters.length {
                let char = &self.characters[i] as &CharacterInstance
                maxHealth = AutoGame.maxUInt8(maxHealth, char.health)
                maxAttack = AutoGame.maxUInt8(maxAttack, char.attack)
                maxDefend = AutoGame.maxUInt8(maxDefend, char.defend)
                i = i + 1
            }

            return {
                "health": maxHealth,
                "attack": maxAttack,
                "defend": maxDefend
            }
        }

        // Count characters by type
        access(all) fun getCharacterTypeCounts(): {String: Int} {
            let counts: {String: Int} = {}
            
            var i = 0
            while i < self.characters.length {
                let char = &self.characters[i] as &CharacterInstance
                let charType = char.template.characterType
                if counts[charType] != nil {
                    counts[charType] = counts[charType]! + 1
                } else {
                    counts[charType] = 1
                }
                i = i + 1
            }

            return counts
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- AutoGame.createEmptyCollection(nftType: Type<@Roster>())
        }
    }


    ///////////////////////////////////////////////////////////////////
    // Roster Collection resource
    ///////////////////////////////////////////////////////////////////

    access(all) resource RosterCollection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init () {
            self.ownedNFTs <- {}
        }

        /// getSupportedNFTTypes returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@Roster>()] = true
            return supportedTypes
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@Roster>()
        }

        /// withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("RosterCollection.withdraw: Could not withdraw an NFT with ID "
                        .concat(withdrawID.toString())
                        .concat(". Check the submitted ID to make sure it is one that this collection owns."))

            return <-token
        }

        /// deposit takes a NFT and adds it to the collections dictionary
        /// and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @Roster
            let id = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[token.id] <- token

            destroy oldToken
        }

        // NonFungibleToken.CollectionPublic
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }


        access(all) fun borrowRoster(at index: UInt64): &Roster? {
            if let nft: &{NonFungibleToken.NFT} = &self.ownedNFTs[index] {
                return nft as? &Roster
            } else {
                return nil
            }
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- AutoGame.createEmptyCollection(nftType: Type<@Roster>())
        }
    }


    ///////////////////////////////////////////////////////////////////
    // Elo algorithm configuration
    ///////////////////////////////////////////////////////////////////
 
    access(all) struct EloConfig {
        // K-factors for different player categories
        access(all) let provisionalKFactor: Fix64  // For new players
        access(all) let standardKFactor: Fix64     // For established players
        access(all) let masterKFactor: Fix64       // For high-rated players
        
        // Rating thresholds
        access(all) let masterRatingThreshold: Fix64
        access(all) let provisionalGamesThreshold: UInt32

        init(
            provisionalKFactor: Fix64,
            standardKFactor: Fix64,
            masterKFactor: Fix64,
            masterRatingThreshold: Fix64,
            provisionalGamesThreshold: UInt32
        ) {
            self.provisionalKFactor = provisionalKFactor
            self.standardKFactor = standardKFactor
            self.masterKFactor = masterKFactor
            self.masterRatingThreshold = masterRatingThreshold
            self.provisionalGamesThreshold = provisionalGamesThreshold
        }
    }
    
    
    ///////////////////////////////////////////////////////////////////
    // Contract-level Elo configuration
    ///////////////////////////////////////////////////////////////////

    access(all) let eloConfig: EloConfig


    ///////////////////////////////////////////////////////////////////
    // Player resource representing a player in the game
    ///////////////////////////////////////////////////////////////////

    access(all) resource Player {
        access(all) var wins: UInt32
        access(all) var losses: UInt32
        access(all) var draws: UInt32
        access(all) var elo: Fix64
        access(all) var gold: UInt32
        access(all) var ribbons: UInt32
        access(all) let roster: @Roster
        
        // Track total games for provisional status
        access(all) var totalGames: UInt32

        init() {
            self.wins = 0
            self.losses = 0
            self.draws = 0
            self.elo = Fix64(1000.0) // Starting ELO rating
            self.gold = 0
            self.ribbons = 0
            self.roster <- create Roster()
            self.totalGames = 0
        }

        // Check if player is still provisional
        access(all) fun isProvisional(): Bool {
            return self.totalGames < AutoGame.eloConfig.provisionalGamesThreshold
        }

        // Get appropriate K-factor based on player status
        access(all) fun getKFactor(): Fix64 {
            if self.isProvisional() {
                return AutoGame.eloConfig.provisionalKFactor
            } else if self.elo >= AutoGame.eloConfig.masterRatingThreshold {
                return AutoGame.eloConfig.masterKFactor
            }
            return AutoGame.eloConfig.standardKFactor
        }
    }


    ///////////////////////////////////////////////////////////////////
    // Events for battle state changes
    ///////////////////////////////////////////////////////////////////

    access(all) event BattleStarted(player1: Address, player2: Address)
    access(all) event TurnStarted(turnNumber: UInt32)
    access(all) event CharactersFighting(player1Character: String, player2Character: String)
    access(all) event AttackPerformed(attacker: String, defender: String, damage: UInt8, remainingHealth: UInt8)
    access(all) event CharacterFainted(character: String)
    access(all) event TurnEnded(winner: Address, loser: Address)
    access(all) event BattleEnded(winner: Address, loser: Address, turns: UInt32)
    access(all) event EloUpdated(player: Address, oldElo: Fix64, newElo: Fix64, change: Fix64)
    access(all) event CharacterAttack(attacker: String, defender: String, damage: UInt8, remainingHealth: UInt8)
    access(all) event CharacterDefeated(character: String)


    ///////////////////////////////////////////////////////////////////
    // Game state enum to track battle progress
    ///////////////////////////////////////////////////////////////////

    access(all) enum GameState: UInt8 {
        access(all) case Initial
        access(all) case Started
        access(all) case Finished
        access(all) case Error
    }


    ///////////////////////////////////////////////////////////////////
    // Battle resource to manage combat between two players
    ///////////////////////////////////////////////////////////////////

    access(all) resource Battle {
        access(self) let player1Address: Address
        access(self) let player2Address: Address
        access(self) var player1Roster: @Roster
        access(self) var player2Roster: @Roster
        access(self) var gameState: GameState
        access(self) var winner: Address?
        access(self) var loser: Address?
        
        // Track current battle state
        access(self) var currentTurn: UInt32
        access(self) var numTurns: UInt32
        access(self) var player1Wins: UInt32
        access(self) var player2Wins: UInt32

        init(
            player1Address: Address,
            player2Address: Address,
            player1Roster: @Roster,
            player2Roster: @Roster
        ) {
            self.player1Address = player1Address
            self.player2Address = player2Address
            self.player1Roster <- player1Roster
            self.player2Roster <- player2Roster
            self.gameState = GameState.Initial
            self.winner = nil
            self.loser = nil
            self.currentTurn = 1
            self.numTurns = 10
            self.player1Wins = 0
            self.player2Wins = 0
            assert(self.player1Roster.getLength() == self.player2Roster.getLength(), message: "Battle constructor: Player rosters must have the same length")  
        }

        access(all) fun startBattle() {
            pre {
                self.gameState == GameState.Initial: "Battle must be in Initial state to start"
            }
            self.gameState = GameState.Started
        }

        access(all) fun characterAttack(attacker: &CharacterInstance, defender: &CharacterInstance, currentDefenderDamage: UInt8): UInt8 {
            let attackDamage = attacker.calculateDamage(defender: defender)
            let newDefenderDamage = currentDefenderDamage - attackDamage
                emit CharacterAttack(
                    attacker: attacker.template.characterType,
                    defender: defender.template.characterType,
                    damage: attackDamage,
                    remainingHealth: defender.health >= newDefenderDamage ? defender.health - newDefenderDamage : 0
                )

                return newDefenderDamage
        }

        access(all) fun executeRound(number: Int, char1: &CharacterInstance, char2: &CharacterInstance, currentChar1Damage: UInt8, currentChar2Damage: UInt8): [UInt8; 2] {
                var newCurrentCharDamages: [UInt8; 2] = [currentChar1Damage, currentChar2Damage]
                // Alternate attack initiative
                if number % 2 == 1 {
                    // char1 attacks first
                    newCurrentCharDamages[1] = self.characterAttack(attacker: char1, defender: char2, currentDefenderDamage: currentChar2Damage)
                    if newCurrentCharDamages[1] < char2.health {
                        newCurrentCharDamages[0] = self.characterAttack(attacker: char2, defender: char1, currentDefenderDamage: currentChar1Damage)
                    }
                } else {
                    // char2 attacks first
                    newCurrentCharDamages[0] = self.characterAttack(attacker: char2, defender: char1, currentDefenderDamage: currentChar1Damage)
                    if newCurrentCharDamages[0] < char1.health {
                        newCurrentCharDamages[1] = self.characterAttack(attacker: char1, defender: char2, currentDefenderDamage: currentChar2Damage)
                    }
                }
                return newCurrentCharDamages
        }

        access(all) fun determineTurnWinner(roster1Index: Int, roster2Index: Int) {
            // Who has the more characters left? They win the turn.
            if roster1Index > roster2Index {
                self.player1Wins = self.player1Wins + 1
            } else {
                self.player2Wins = self.player2Wins + 1
            }
        }

        access(all) fun determineGameWinner() {
            if self.player1Wins > self.player2Wins {
                    self.winner = self.player1Address
                    self.loser = self.player2Address
                } else if self.player2Wins > self.player1Wins {
                    self.winner = self.player2Address
                    self.loser = self.player1Address
                } else {
                    // Tie, no winner
                }
        }

        access(all) fun updateGameState() {
            self.currentTurn = self.currentTurn + 1
            // If we have finished the battle.
            if self.currentTurn > self.numTurns {
                self.gameState = GameState.Finished
                self.determineGameWinner()
            }
        }

        access(all) fun executeTurn() {
            pre {
                self.gameState == GameState.Started: "Battle must be in Started state to execute turn"
                self.currentTurn < self.numTurns: "Battle is already over"
            }

            // Battle each pair of characters
            var roster1Index = 0
            var roster2Index = 0
            var roundNumber = 0

            // Rosters are same length, and we currently own them.
            while roster1Index < self.player1Roster.getLength() && roster2Index < self.player1Roster.getLength() {
                let char1 = self.player1Roster.borrowCharacterAt(roster1Index)
                if char1 == nil {
                    self.gameState = GameState.Error
                }
                let char2 = self.player2Roster.borrowCharacterAt(roster2Index)
                if char2 == nil {
                    self.gameState = GameState.Error
                }
                
                emit CharactersFighting(
                    player1Character: char1.template.characterType,
                    player2Character: char2.template.characterType
                )
         
                var charDamages: [UInt8; 2] = [0, 0]
                while charDamages[0] < char1.health && charDamages[1] < char2.health {
                    roundNumber = roundNumber + 1
                    charDamages = self.executeRound(number: roundNumber, char1: char1, char2: char2, currentChar1Damage: charDamages[0], currentChar2Damage: charDamages[1])
                }

                if charDamages[0] >= char1.health {
                    roster1Index = roster1Index + 1
                    emit CharacterFainted(character: char1.template.characterType)
                }

                if charDamages[1] >= char2.health {
                    roster2Index = roster2Index + 1
                    emit CharacterFainted(character: char2.template.characterType)
                }
            }

            self.determineTurnWinner(roster1Index: roster1Index, roster2Index: roster2Index)

            self.updateGameState()
        }
    }


    ///////////////////////////////////////////////////////////////////
    // Contract-level Init function
    ///////////////////////////////////////////////////////////////////

    init() {
        self.CharacterStoragePath = /storage/AutoGameCharacterInstance
        self.CharacterPublicPath = /public/AutoGameCharacterInstance
        self.RosterStoragePath = /storage/AutoGameRoster
        self.RosterPublicPath = /public/AutoGameRoster
        
        self.totalCharacterSupply = 0
        self.totalRosterSupply = 0
        
        self.characterTemplates = {}
        self.eloConfig = EloConfig(
            provisionalKFactor: Fix64(40.0),
            standardKFactor: Fix64(32.0),
            masterKFactor: Fix64(24.0),
            masterRatingThreshold: Fix64(2200.0),
            provisionalGamesThreshold: 30
        )

        emit ContractInitialized()
    }


}
