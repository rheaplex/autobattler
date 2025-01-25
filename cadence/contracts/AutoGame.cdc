import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

access(all) contract AutoGame {

    // -----------------------------------------------------------
    // PUBLIC PATHS 
    // -----------------------------------------------------------

    // Where the user's Collection is stored in their account
    access(all) let CardCollectionStoragePath: StoragePath
    // Where a public capability to the Collection is made available
    access(all) let CardCollectionPublicPath: PublicPath
    // The minter resource
    access(all) let CardMinterStoragePath: StoragePath
    // The player's current battle
    access(all) let BattleCurrentStoragePath: StoragePath

    // -----------------------------------------------------------
    // CARD NFTS
    // -----------------------------------------------------------

    access(all) resource Card: NonFungibleToken.NFT {
        // The unique ID required by the NFT standard
        access(all) let id: UInt64

        // Attributes
        access(all) var name: String
        access(all) var url: String
        access(all) var attack: UInt32
        access(all) var health: UInt32
        access(all) var level: UInt8

        init(
            initName: String,
            initUrl: String,
            initAttack: UInt32,
            initHealth: UInt32,
            initLevel: UInt8
        ) {
            self.id = self.uuid
            self.url = initUrl
            self.name = initName
            self.attack = initAttack
            self.health = initHealth
            self.level = initLevel
        }

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
                        name: self.name,
                        description: "AutoGame Character",
                        thumbnail: MetadataViews.HTTPFile(url: self.url)
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits([
                        MetadataViews.Trait(name:"health", value: self.health, displayType: "Number", rarity: nil  ),
                        MetadataViews.Trait(name:"attack", value: self.attack, displayType: "Number", rarity: nil  )
                    ])
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: AutoGame.CardCollectionStoragePath,
                        publicPath: AutoGame.CardCollectionPublicPath,
                        publicCollection: Type<&AutoGame.CardCollection>(),
                        publicLinkedType: Type<&AutoGame.CardCollection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-AutoGame.createEmptyCollection(nftType: Type<@Card>())
                        })
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @CardCollection {
            return <- create CardCollection()
        }
    }

    // -----------------------------------------------------------
    // CARD COLLECTION
    // -----------------------------------------------------------

    access(all) resource CardCollection: NonFungibleToken.Collection {
        // The internal dictionary of owned NFTs
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[Type<@Card>()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@Card>()
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun borrowCard(id: UInt64): &Card {
           let nft: &{NonFungibleToken.NFT}? = &self.ownedNFTs[id]
           return nft as! &Card
        }

        // Required by the standard to return a withdrawn NFT
        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Missing NFT in Collection.")
            return <- token
        }

        // Required deposit method from the NFT standard
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let id: UInt64 = token.id
            // Ensure no existing NFT with same ID
            if self.ownedNFTs[id] != nil {
                panic("NFT with this ID already exists in Collection!")
            }
            self.ownedNFTs[id] <-! token
        }

        // Return an array of all NFT IDs in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) fun createEmptyCollection(): @CardCollection {
            return <- create CardCollection()
        }

        init() {
            self.ownedNFTs <- {}
        }
    }

    // -----------------------------------------------------------
    // MINTER RESOURCE
    // -----------------------------------------------------------

    access(all) resource CardMinter {

        access(all) fun mintCard(
            name: String,
            url: String,
            attack: UInt32,
            health: UInt32,
            level: UInt8
        ): @{NonFungibleToken.NFT} {
            // Create the new Card NFT
            let newCard <-create Card(
                initName: name,
                initUrl: url,
                initAttack: attack,
                initHealth: health,
                initLevel: level
            )

            // Deposit into the recipient's Collection
            return <- newCard
        }
    }

    // -----------------------------------------------------------
    // MINTER SINGLETON
    // -----------------------------------------------------------

    access(all) let minter: @CardMinter

    // -----------------------------------------------------------
    // EVENTS FOR BATTLES
    // -----------------------------------------------------------

    access(all) event BattleCreated(
        battleID: UInt64,
        team1IDs: [UInt64],
        team2IDs: [UInt64]
    )

    access(all) event BattleTurnAdvanced(
        battleID: UInt64,
        turnIndex: UInt64,
        attackerCardID: UInt64,
        defenderCardID: UInt64,
        damageToAttacker: UInt32,
        damageToDefender: UInt32,
        newAttackerHealth: UInt32,
        newDefenderHealth: UInt32
    )

    access(all) event CardFainted(
        battleID: UInt64,
        cardID: UInt64
    )

    access(all) event BattleEnded(
        battleID: UInt64,
        winner: Address?,
        loser: Address?
    )

    // -----------------------------------------------------------
    // BATTLE ID COUNTER
    // -----------------------------------------------------------
  
    access(all) var battleCounter: UInt64

    // -----------------------------------------------------------
    // BATTLE RESOURCE
    // -----------------------------------------------------------
 
      access(all) resource Battle {
        access(all) let battleID: UInt64

        access(all) let team1Cap: Capability<&CardCollection>
        access(all) let team2Cap: Capability<&CardCollection>

        access(all) let team1CardIDs: [UInt64]
        access(all) let team2CardIDs: [UInt64]

        // Indices into the Card ID arrays indicating who is "up next."
        access(self) var t1Index: Int
        access(self) var t2Index: Int

        access(all) var team1CardHealth: UInt32
        access(all) var team2CardHealth: UInt32

        // Whether the battle has ended (no more turns allowed)
        access(self) var ended: Bool

        // Keep track of how many turns have been processed
        access(self) var turnIndex: UInt64

        init(
            battleID: UInt64,
            cap1: Capability<&CardCollection>,
            cap2: Capability<&CardCollection>,
            ids1: [UInt64],
            ids2: [UInt64]
        ) {
            self.battleID = battleID
            self.team1Cap = cap1
            self.team2Cap = cap2
            self.team1CardIDs = ids1
            self.team2CardIDs = ids2

            self.t1Index = 0
            self.t2Index = 0

            self.team1CardHealth = 0
            self.team2CardHealth = 0

            self.ended = false

            self.turnIndex = 0
        }

        // This function executes exactly ONE "exchange of blows."
        // We require that BOTH players sign the transaction that calls this,
        // ensuring mutual agreement before each turn advances.
        access(all) fun advanceTurn() {
            // If the battle is already ended, do nothing
            pre {
                !self.ended: "Battle has already ended."
            }

            // Borrow references
            let team1Ref = self.team1Cap.borrow() 
                ?? panic("Could not borrow Team1's collection reference.")
            let team2Ref = self.team2Cap.borrow()
                ?? panic("Could not borrow Team2's collection reference.")

            // Grab the front-line Cards
            let Card1: &Card = team1Ref.borrowCard(id: self.team1CardIDs[self.t1Index])
            let Card2: &Card = team2Ref.borrowCard(id: self.team2CardIDs[self.t2Index])

            let damageToCard1 = Card2.attack
            let damageToCard2 = Card1.attack

            // Apply damage
            self.team1CardHealth = Card1.health - damageToCard1
            self.team2CardHealth = Card2.health - damageToCard2

            // Increment turnIndex
            self.turnIndex = self.turnIndex + 1

            // Emit an event for the turn
            emit BattleTurnAdvanced(
                battleID: self.battleID,
                turnIndex: self.turnIndex,
                attackerCardID: Card1.id,
                defenderCardID: Card2.id,
                damageToAttacker: damageToCard1,
                damageToDefender: damageToCard2,
                newAttackerHealth: self.team1CardHealth,
                newDefenderHealth: self.team2CardHealth
            )

            // Check for faints
            if self.team1CardHealth <= 0 {
                emit CardFainted(battleID: self.battleID, cardID: Card1.id)
                self.t1Index = self.t1Index + 1
            }

            if self.team2CardHealth <= 0 {
                emit CardFainted(battleID: self.battleID, cardID: Card2.id)
                self.t2Index = self.t2Index + 1
            }

            // If a team is out of Cards after that exchange, we finalize
            if self.t1Index >= self.team1CardIDs.length || self.t2Index >= self.team2CardIDs.length {
                self.ended = true
                self.emitResult()
            }
        }

        // Helper function to produce a final result string
        access(self) fun emitResult() {
            if self.t1Index > self.t2Index {
                // Player 1 wins
                emit BattleEnded(battleID: self.battleID, winner: self.team1Cap.address, loser: self.team2Cap.address)
            } else if self.t2Index > self.t1Index {
                // Player 2 wins
                emit BattleEnded(battleID: self.battleID, winner: self.team2Cap.address, loser: self.team1Cap.address)
            }
            // Draw
            emit BattleEnded(battleID: self.battleID, winner: nil, loser: nil)
        }
    }

    // -----------------------------------------------------------
    // CREATE BATTLE
    // -----------------------------------------------------------
 
    access(all) fun createBattle(
        team1Cap: Capability<&CardCollection>,
        team2Cap: Capability<&CardCollection>,
        team1IDs: [UInt64],
        team2IDs: [UInt64]
    ): @Battle {
        self.battleCounter = self.battleCounter + 1
        let newBattleID = self.battleCounter

        let newBattle <- create Battle(
            battleID: newBattleID,
            cap1: team1Cap,
            cap2: team2Cap,
            ids1: team1IDs,
            ids2: team2IDs
        )

        emit BattleCreated(
            battleID: newBattleID,
            team1IDs: team1IDs,
            team2IDs: team2IDs
        )
        return <- newBattle
    }

    // -----------------------------------------------------------
    // CONTRACT-LEVEL NFT FUNCTIONS
    // -----------------------------------------------------------

 access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create CardCollection()
    }

    // -----------------------------------------------------------
    // CONTRACT INIT
    // -----------------------------------------------------------

    init() {
        self.CardCollectionStoragePath = /storage/AutoGameCardsCollection
        self.CardCollectionPublicPath = /public/AutoGameCardsCollection
        self.CardMinterStoragePath = /storage/AutoGameCardsMinter
        self.BattleCurrentStoragePath = /storage/AutoGameBattleCurrent
        
        self.battleCounter = 0

        // Create the single shared Minter resource
        self.minter <- create CardMinter()
    }
}
