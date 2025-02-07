import "FlowToken"
import "NonFungibleToken"
import "RandomBeaconHistory"

import "Xorshift128plus"

access(all) contract AutoGame {

    // -----------------------------------------------------------
    // PUBLIC PATHS - JUST SAY NO
    // -----------------------------------------------------------

    access(all) let DomainCollectionStoragePath: StoragePath
    access(all) let DomainCollectionPublicPath: PublicPath
    access(all) let RunCollectionStoragePath: StoragePath
    access(all) let RunCollectionPublicPath: PublicPath




    // -----------------------------------------------------------
    // ENUMS
    // -----------------------------------------------------------

    access(all) enum BattleProgress: UInt8 {
        // Just two states: battle created and started but not resolved yet,
        // and battle resolved.
        //access(all) case NotStarted
        access(all) case InProgress
        access(all) case Resolved
    }

    access(all) enum BattleResult: UInt8 {
        access(all) case Undecided
        access(all) case Win
        access(all) case Lose
        access(all) case Draw
    }

    // -----------------------------------------------------------
    // EVENTS
    // -----------------------------------------------------------

    access(all) event DomainCreated(
        id: UInt64
    )

    access(all) event DomainDestroyed(
        id: UInt64
    )

    access(all) event DomainStarted(
        id: UInt64,
        payment: UFix64
    )

    access(all) event DomainCollectionCreated(
        owner: Address
    )

    access(all) event RunCreated(
        id: UInt64,
        DomainId: UInt64
    )

    access(all) event RunDestroyed(
        id: UInt64
    )

    access(all) event RunCollectionCreated(
        owner: Address
    )

    // -----------------------------------------------------------
    // INTERFACES
    // -----------------------------------------------------------

    access(all) struct interface EntityMetadata {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let url: String
    }

    access(all) struct interface BattleState {
        access(all) var myTeam: [UInt64]
        access(all) var myGold: UInt8
        access(all) var myHearts: UInt8
        access(all) var myRibbons: UInt8
        access(all) var theirTeam: [UInt64]
        access(all) var theirGold: UInt8
        access(all) var theirHearts: UInt8
        access(all) var theirRibbons: UInt8
        access(all) let entityStates: {UInt64: {UInt64: UInt8}}

        access(all) fun copy(): {BattleState}
        access(all) fun setMyTeam(_ team: [UInt64]) {
            self.myTeam = team
        }
        access(all) fun setMyGold(_ gold: UInt8) {
            self.myGold = gold
        }
        access(all) fun setMyHearts(_ hearts: UInt8) {
            self.myHearts = hearts
        }
        access(all) fun setMyRibbons(_ ribbons: UInt8) {
            self.myRibbons = ribbons
        }
        access(all) fun setTheirTeam(_ team: [UInt64]) {
            self.theirTeam = team
        }
        access(all) fun setTheirGold(_ gold: UInt8) {
            self.theirGold = gold
        }
        access(all) fun setTheirHearts(_ hearts: UInt8) {
            self.theirHearts = hearts
        }
        access(all) fun setTheirRibbons(_ ribbons: UInt8) {
            self.theirRibbons = ribbons
        }
    }

    access(all) resource interface Battle {
        access(all) let id: UInt64
        access(all) var progress: BattleProgress
        access(all) var result: BattleResult
        access(all) let initialState: {BattleState}
        access(all) let DomainCollection: Capability<&DomainCollection>
        access(all) let DomainId: UInt64

        access(all) fun start()
        access(all) fun resolve(): [{BattleState}]
        access(all) fun replay(): [{BattleState}]
    }

    access(all) resource interface Run {
        access(all) let id: UInt64
        access(all) let DomainCollection: Capability<&DomainCollection>
        access(all) let DomainId: UInt64
        access(all) var battles: @[{Battle}]

        access(all) fun createBattle(): UInt64
        access(all) fun battleCount(): Int
        access(all) fun borrowBattle(index: Int): &{Battle}
    }

// Nope. Entities are object implementing an interface. Any functions go through the Domain.
//       Instances of the entity?
//       Create copy/ref rather than switch statements!
//       Domain has list of objects.
    access(all) resource interface EntityLibrary {
        access(all) let id: UInt64
        access(all) fun getEntityIDs(): [UInt64]
        access(all) fun getEntityMetadata(id: UInt64): &{EntityMetadata}
        access(all) fun updateBattleStateForEntity(id: UInt64, state: {BattleState}): {BattleState}
    }

    access(all) resource interface Domain: EntityLibrary {
        access(all) let id: UInt64

        access(all) fun start(payment: @FlowToken.Vault,DomainCollection: Capability<&DomainCollection>): @{Run}
        access(all) fun getRunPrice(): UFix64
    }

    //-----------------------------------------------------------
    // DEFAULT IMPLEMENTATIONS
    //-----------------------------------------------------------

    access(all) struct StandardEntityMetadata: EntityMetadata {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let url: String

        init(id: UInt64, name: String, url: String) {
            self.id = id
            self.name = name
            self.url = url
        }
    }

    access(all) struct StandardBattleState: BattleState {
        access(all) var myTeam: [UInt64]
        access(all) var myGold: UInt8
        access(all) var myHearts: UInt8
        access(all) var myRibbons: UInt8
        access(all) var theirTeam: [UInt64]
        access(all) var theirGold: UInt8
        access(all) var theirHearts: UInt8
        access(all) var theirRibbons: UInt8
    
        access(all) let entityStates: {UInt64: {UInt64: UInt8}}

        init(
            myTeam: [UInt64],
            myGold: UInt8,
            myHearts: UInt8,
            myRibbons: UInt8,
            theirTeam: [UInt64],
            theirGold: UInt8,
            theirHearts: UInt8,
            theirRibbons: UInt8,
            entityStates: {UInt64: {UInt64: UInt8}}
        ) {
            self.myTeam = myTeam
            self.myGold = myGold
            self.myHearts = myHearts
            self.myRibbons = myRibbons
            self.theirTeam = theirTeam
            self.theirGold = theirGold
            self.theirHearts = theirHearts
            self.theirRibbons = theirRibbons
            self.entityStates = entityStates
        }

        access(all) fun copy(): {BattleState} {
            return StandardBattleState(
                myTeam: self.myTeam,
                myGold: self.myGold,
                myHearts: self.myHearts,
                myRibbons: self.myRibbons,
                theirTeam: self.theirTeam,
                theirGold: self.theirGold,
                theirHearts: self.theirHearts,
                theirRibbons: self.theirRibbons,
                entityStates: self.entityStates
            )
        }
    }

    access(all) resource StandardBattle: Battle {
        access(all) let id: UInt64
        access(all) var progress: BattleProgress
        access(all) var result: BattleResult
        access(all) let initialState: {BattleState}
        access(all) var randomnessBlock: UInt64
        access(all) var randomnessFulfilled: Bool
        access(all) let DomainCollection: Capability<&DomainCollection>
        access(all) let DomainId: UInt64

        //FIXME: take from shop phase, and previous battles
        init(DomainCollection: Capability<&DomainCollection>, DomainId: UInt64, initialState: {BattleState}) {
            self.id = self.uuid
            self.initialState = initialState
            self.randomnessBlock = 0
            self.randomnessFulfilled = false
            self.progress = BattleProgress.NotStarted
            self.result = BattleResult.Undecided
            self.DomainCollection = DomainCollection
            self.DomainId = DomainId
        }

        access(all) fun start() {
            pre {
                self.progress == BattleProgress.NotStarted: "Battle already started"
            }
            self.progress = BattleProgress.InProgress
            self.randomnessBlock = getCurrentBlock().height
        }

        access(all) fun resolve(): [{BattleState}] {
            pre {
                self.progress == BattleProgress.InProgress: "Battle not in progress"
                !self.randomnessFulfilled: "Randomness already fulfilled"
            }
            //---- self._fulfillRandomness()
            self.progress = BattleProgress.Resolved
            // Record the battle result onchain.
            let turns = self.replay()
            self.result = self.battleResult(turns: turns)
            return turns
        }
        
        access(all) fun battleResult(turns: [{BattleState}]): BattleResult {
            pre {
                self.progress == BattleProgress.Resolved: "Battle not resolved"
            }
            let lastTurn = turns[turns.length - 1]
            let a = lastTurn.myTeam.length
            let b = lastTurn.theirTeam.length
            if a > b {
                return BattleResult.Win
            } else if a < b {
                return BattleResult.Lose
            } else {
                return BattleResult.Draw
            }
        }

        access(all) fun replay(): [{BattleState}] {
            pre {
                self.progress == BattleProgress.Resolved: "Battle not resolved"
            }
            //FIXME: Debug on emulator!
            let seed: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]//----self.randSeed()
            //FIXME: Use real salt!!!
            let salt: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            let rng = Xorshift128plus.PRG(
                sourceOfRandomness: seed,
                salt: salt
            )
            let Domain = self.DomainCollection.borrow()!.borrowDomain(id: self.DomainId)
            let turns: [{BattleState}] = [self.initialState]
            var it_is_so_on = true
            while it_is_so_on {
                let prevState = turns[turns.length - 1]
                var turn = prevState.copy()
                for entity in prevState.myTeam {
                    turn = Domain.updateBattleStateForEntity(id: entity, state: turn)
                    if turn.myTeam.length == 0 || turn.theirTeam.length == 0 {
                        it_is_so_on = false
                    }
                }
                for entity in prevState.theirTeam {
                    turn = Domain.updateBattleStateForEntity(id: entity, state: turn)
                    if turn.myTeam.length == 0 || turn.theirTeam.length == 0{
                        it_is_so_on = false
                    }
                }
                turns.append(turn)
                if turns.length > 100 {
                    panic(
                        "Too many turns in the battle "
                        .concat(turn.myTeam.length.toString()) 
                        .concat(" ")
                        .concat(turn.theirTeam.length.toString()) 
                    )
                }
            }
            return turns
        }

        access(all) fun randSeed(): [UInt8] {
            return RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value
        }

        access(self) fun _fulfillRandomness() {
            pre {
                !self.randomnessFulfilled:
                "RandomConsumer.Request.fulfill(): The random request has already been fulfilled."
                self.randomnessBlock < getCurrentBlock().height:
                "RandomConsumer.Request.fulfill(): Cannot fulfill random request before the eligible block height of "
                .concat((self.randomnessBlock + 1).toString())
            }
            self.randomnessFulfilled = true

        }
    }

    access(all) resource StandardRun: Run {
        access(all) let id: UInt64
        access(all) let DomainCollection: Capability<&DomainCollection>
        access(all) let DomainId: UInt64
        access(all) var battles: @[{Battle}]

        init(DomainCollection: Capability<&DomainCollection>, DomainId: UInt64) {
            self.DomainCollection = DomainCollection
            self.DomainId = DomainId
            self.id = self.uuid
            self.battles <- []
        }

        access(all) fun createBattle(): UInt64 {
            // The state prior to the first turn
            let initialState = StandardBattleState(
                myTeam: [1, 2, 3, 100, 5, 6, 7, 8, 9, 4],
                myGold: 10,
                myHearts: 3,
                myRibbons: 0,
                theirTeam: [9, 2, 7, 4, 8, 5, 1, 6, 10, 3],
                theirGold: 10,
                theirHearts: 3,
                theirRibbons: 0,
                entityStates: {}
            )
            let Domain = self.DomainCollection.borrow()!.borrowDomain(id: self.DomainId)
            if Domain.id != self.DomainId {
                panic("Wrong Domain returned by collection")
            }
            let battle <- create StandardBattle(DomainCollection: self.DomainCollection, DomainId: self.DomainId, initialState: initialState)
            let battleID = battle.id
            self.battles.append(<-battle)
            return battleID
        }

        access(all) fun borrowBattle(index: Int): &{Battle} {
            pre {
                index < self.battles.length
            }
            return &(self.battles[index])
        }

        access(all) fun battleCount(): Int {
            return self.battles.length
        }
    }

    access(all) resource StandardDomain: Domain, EntityLibrary {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let url: String
        access(all) var runPrice: UFix64

        access(all) var entityIDs: [UInt64]
        access(all) var entityMetadatas: {UInt64: StandardEntityMetadata}

        init(name: String, url: String, runPrice: UFix64) {
            self.id = self.uuid
            self.name = name
            self.url = url
            self.entityIDs = []
            self.entityMetadatas = {}
            self.runPrice = runPrice
        }

        access(all) fun start(payment: @FlowToken.Vault, DomainCollection: Capability<&DomainCollection>): @{Run} {
            destroy payment
            return <- create StandardRun(DomainCollection: DomainCollection, DomainId: self.id)
        }

        access(all) fun getEntityIDs(): [UInt64] {
            return self.entityIDs
        }

        access(all) fun getEntityMetadata(id: UInt64): &{EntityMetadata} {
            if let metadata: &{EntityMetadata} = &self.entityMetadatas[id] {
                return metadata
            } else {
                panic("Entity not found")
            }
        }

        access(all) fun updateBattleStateForEntity(id: UInt64, state: {BattleState}): {BattleState} {
            pre {
                !self.entityIDs.contains(id): "Entity not found"
            }
            switch (id) {
                default:
                    state.setTheirTeam([])
            }
            return state
        }

        access(all) fun getRunPrice(): UFix64 {
            return self.runPrice
        }
    }

    //-----------------------------------------------------------
    // COLLECTIONS
    //-----------------------------------------------------------

    access(all) resource DomainCollection {
        access(all) let ownedDomains: @{UInt64: {Domain}}

        init() {
            self.ownedDomains <- {}
        }

        access(all) fun deposit(Domain: @{Domain}) {
            pre {
                !self.ownedDomains.keys.contains(Domain.id): "Domain already exists"
            }
            var prev <- self.ownedDomains[Domain.id] <- Domain
            destroy prev
        }

        access(all) fun getLength(): Int {
            return self.ownedDomains.length
        }

        access(all) fun borrowDomain(id: UInt64): &{Domain} {
            if let Domain: &{Domain} = &self.ownedDomains[id] {
                return Domain
            } else {
                panic("Domain not found")
            }
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedDomains.keys
        }

        access(all) fun forEachID(_ f: fun (UInt64): Bool): Void {
            self.ownedDomains.forEachKey(f)
        }
    }

    access(all) resource RunCollection {
        access(all) let ownedRuns: @{UInt64: {Run}}

        init() {
            self.ownedRuns <- {}
        }

        access(all) fun deposit(run: @{Run}) {
            pre {
                !self.ownedRuns.keys.contains(run.id): "Run already exists"
            }
            var prev <- self.ownedRuns[run.id] <- run
            destroy prev
        }

        access(all) fun getLength(): Int {
            return self.ownedRuns.length
        }

        access(all) fun borrowRun(id: UInt64): &{Run} {
            if let run: &{Run} = &self.ownedRuns[id] {
                return run
            } else {
                panic("Run not found")
            }
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedRuns.keys
        }

        access(all) fun forEachID(_ f: fun (UInt64): Bool): Void {
            self.ownedRuns.forEachKey(f)
        }
    }

    // -----------------------------------------------------------
    // PUBLIC FUNCTIONS
    // -----------------------------------------------------------

    access(all) fun createStandardDomain(name: String, url: String, runPrice: UFix64): @{Domain} {
        let Domain <- create StandardDomain(name: name, url: url, runPrice: runPrice)
        return <- Domain
    }

    access(all) fun createEmptyDomainCollection(): @DomainCollection {
        let collection <- create DomainCollection()
        emit DomainCollectionCreated(owner: self.account.address)
        return <- collection
    }

    access(all) fun createEmptyRunCollection(): @RunCollection {
        let collection <- create RunCollection()
        emit RunCollectionCreated(owner: self.account.address)
        return <- collection
    }

    // -----------------------------------------------------------
    // CONTRACT INITIALIZER
    // -----------------------------------------------------------

    init() {
        self.DomainCollectionStoragePath = StoragePath(identifier: "DomainCollectionStorage")!
        self.DomainCollectionPublicPath = PublicPath(identifier: "DomainCollectionPublic")!

        self.RunCollectionStoragePath = StoragePath(identifier: "runCollectionStorage")!
        self.RunCollectionPublicPath = PublicPath(identifier: "runCollectionPublic")!
    }
}