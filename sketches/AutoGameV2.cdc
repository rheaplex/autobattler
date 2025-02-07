import "FlowToken"
import "NonFungibleToken"
import "RandomBeaconHistory"

import "Xorshift128plus"

access(all) contract AutoGame {

    // -----------------------------------------------------------
    // PUBLIC PATHS 
    // -----------------------------------------------------------

    access(all) let DomainCollectionStoragePath: StoragePath
    access(all) let DomainCollectionPublicPath: PublicPath
    access(all) let RunCollectionStoragePath: StoragePath
    access(all) let RunCollectionPublicPath: PublicPath
    access(all) let EntityCollectionStoragePath: StoragePath
    access(all) let EntityCollectionPublicPath: PublicPath

    // -----------------------------------------------------------
    // EVENTS
    // -----------------------------------------------------------

    access(all) event DomainStarted(
        id: UInt64,
        payment: UFix64
    )

    access(all) event DomainCreated(
        id: UInt64
    )

    access(all) event DomainDestroyed(
        id: UInt64
    )

    access(all) event RunCreated(
        id: UInt64,
        domainId: UInt64
    )

    access(all) event RunDestroyed(
        id: UInt64
    )

    access(all) event DomainCollectionCreated(
        owner: Address
    )

    access(all) event RunCollectionCreated(
        owner: Address
    )

    access(all) event EntityCollectionCreated(
        owner: Address
    )

    // -----------------------------------------------------------
    // EFFECT INTERFACE
    // -----------------------------------------------------------

    access(all) struct interface EffectState {}

    access(all) resource interface Effect {
        access(all) let name: String
        access(all) let url: String
        
        access(all) fun createState(entity: &{AutoGame.Entity}): {EffectState}
        access(all) fun apply(entity: &{AutoGame.Entity}, battle: &Battle, turn: &Turn): Bool
    }

    // -----------------------------------------------------------
    // HEALTH EFFECT
    // -----------------------------------------------------------

    access(all) struct HealthState: EffectState {
        access(all) var health: Int8
        access(all) var attack: Int8
        access(all) var damage: Int8
        access(all) var defence: Int8

        init(health: Int8, attack: Int8, damage: Int8, defence: Int8) {
            self.health = health
            self.attack = attack
            self.damage = damage
            self.defence = defence
        }

        access(all) fun takeDamage(amount: Int8) {
            self.health = self.health - amount
        }

        access(all) fun heal(amount: Int8) {
            self.health = self.health + amount
        }

        access(all) fun fainted(): Bool {
            return self.health <= 0
        }
    }

    access(all) resource Health: Effect {
        access(all) let name: String
        access(all) let url: String
        //FIXME: Starting values.
        access(all) let health: Int8
        access(all) let attack: Int8
        access(all) let damage: Int8
        access(all) let defence: Int8

        init(health: Int8, attack: Int8, damage: Int8, defence: Int8) {
            self.name = "Health"
            self.url = "health.png"  // placeholder URL
            self.health = health
            self.attack = attack
            self.damage = damage
            self.defence = defence
        }

        access(all) fun createState(entity: &{AutoGame.Entity}): {EffectState} {
            return HealthState(
                health: self.health,
                attack: self.attack,
                damage: self.damage,
                defence: self.defence
            )
        }

        access(all) fun stateFor(entity: &{AutoGame.Entity}, turn: &Turn): HealthState? {
            if let state = turn.entityStates[entity.id] {
                if let state = state[self.uuid] {
                    return state as! HealthState
                }
            }
            return nil
        }

        // Apply the health effect to the entity
        //FIXME: this is not correct, we need to store the current value, not the original.
        access(all) fun apply(entity: &{AutoGame.Entity}, battle: &Battle, turn: &Turn): Bool {
            pre{
                turn.myTeam.length > 0 && turn.theirTeam.length > 0: "Health effect can only be applied to an entity with an opposing team"
            }
            if let selfState = self.stateFor(entity: entity, turn: turn) {
                if let otherState = self.stateFor(entity: entity, turn: turn) {
                    if self.defence <= otherState.attack {
                        selfState.takeDamage(amount: otherState.damage)
                    }
                    return true
                }
            }
            return false
        }
    }

    // -----------------------------------------------------------
    // ENTITY INTERFACE
    // -----------------------------------------------------------

    access(all) resource interface Entity {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let url: String
        access(all) let effects: [Capability<&{Effect}>]

        access(all) fun getEffectCount(): Int {
            return self.effects.length
        }

        access(all) fun getEffect(id: UInt64): Capability<&{Effect}> {
            return self.effects[id]
        }

        access(all) fun applyEffects(battle: &Battle, turn: &Turn) : Bool

        access(all) fun getEffectInitialState(id: UInt64): {EffectState}
    }

    // -----------------------------------------------------------
    // STANDARD ENTITY
    // -----------------------------------------------------------

    access(all) resource StandardEntity: Entity {
    access(all) let id: UInt64
        access(all) let name: String
        access(all) let url: String
        access(all) let effects: [Capability<&{Effect}>]

        init(name: String, url: String) {
            self.id = self.uuid
            self.name = name
            self.url = url
            self.effects = []
        }

        access(all) fun applyEffects(battle: &Battle, turn: &Turn) : Bool {
            var handled = false
            for effect in self.effects {
                if let effectRef = effect.borrow() {
                    handled = effectRef.apply(entity: &self as &{AutoGame.Entity}, battle: battle, turn: turn) || handled
                }
            }
            return handled
        }

        access(all) fun getEffectInitialState(id: UInt64): {EffectState} {
            if let effectRef = self.getEffect(id: id).borrow() {
                return effectRef.createState(entity: &self as &{AutoGame.Entity})
            } else {
                panic("Effect not found")
            }
        }

    }

    // -----------------------------------------------------------
    // ENTITY COLLECTION
    // -----------------------------------------------------------

    access(all) resource EntityCollection {
        access(all) var entities: @{UInt64: {Entity}}

        init() {
            self.entities <- {}
        }

        access(all) fun getIDs(): [UInt64] {
            return self.entities.keys
        }

        access(all) fun length(): Int {
            return self.entities.length
        }

        access(all) fun deposit(entity: @{Entity}) {
            let id = entity.id
            self.entities[id] <-! entity
        }

        access(all) fun withdraw(id: UInt64): @{Entity} {
            let entity <- self.entities.remove(key: id) ?? panic("Entity not found")
            return <- entity
        }

        access(all) fun borrowEntity(id: UInt64): &{Entity} {
            if let entity: &{Entity} = &self.entities[id] {
                return entity
            } else {
                panic("Entity not found")
            }
        }
    }

    // -----------------------------------------------------------
    // TURN STRUCT
    // -----------------------------------------------------------

    access(all) struct Turn {
        // Player resources
        access(all) var myGold: UInt64
        access(all) var myHearts: UInt64
        access(all) var myRibbons: UInt64
        access(all) var myTeam: [UInt64]

        // Opponent resources
        access(all) var theirGold: UInt64
        access(all) var theirHearts: UInt64
        access(all) var theirRibbons: UInt64
        access(all) var theirTeam: [UInt64]

        // State
        access(contract) var number: UInt64
        access(all) var entityStates: {UInt64: {UInt64: {EffectState}}}

        init(
            myGold: UInt64,
            myHearts: UInt64,
            myRibbons: UInt64,
            myTeam: [UInt64],
            theirGold: UInt64,
            theirHearts: UInt64,
            theirRibbons: UInt64,
            theirTeam: [UInt64]
        ) {
            self.myGold = myGold
            self.myHearts = myHearts
            self.myRibbons = myRibbons
            self.myTeam = myTeam
            
            self.theirGold = theirGold
            self.theirHearts = theirHearts
            self.theirRibbons = theirRibbons
            self.theirTeam = theirTeam

            // FIXME: walk entities, walk their effects,
            //        call createState() for each on each.
            self.entityStates = {}

            self.number = 0
        }

        access(all) fun next(): Turn {
            var t = Turn(
                myGold: self.myGold,
                myHearts: self.myHearts,
                myRibbons: self.myRibbons,
                myTeam: self.myTeam,
                theirGold: self.theirGold,
                theirHearts: self.theirHearts,
                theirRibbons: self.theirRibbons,
                theirTeam: self.theirTeam
            )
            t.number = self.number + 1
            return t
        }   
    }
    // -----------------------------------------------------------
    // BATTLE STRUCT
    // -----------------------------------------------------------

    access(all) enum BattleState: UInt8 {
        access(all) case NotStarted
        access(all) case InProgress
        access(all) case Resolved
        access(all) case Errored
    }

    access(all) enum BattleResult: UInt8 {
        access(all) case Undecided
        access(all) case Win
        access(all) case Lose
        access(all) case Draw
    }

    access(all) struct Battle {
        access(all) var state: BattleState
        access(all) let randomnessBlock: UInt64
        access(all) var randomnessFulfilled: Bool
        access(all) var myTeam: [UInt64]
        access(all) var theirTeam: [UInt64]
        access(all) var result: BattleResult

        //FIXME: take from shop phase, and previous battles
        init(myTeam: [UInt64], theirTeam: [UInt64]) {
            self.state = BattleState.NotStarted
            self.randomnessBlock = getCurrentBlock().height
            self.randomnessFulfilled = false
            self.myTeam = myTeam
            self.theirTeam = theirTeam
            self.result = BattleResult.Undecided
        }

        access(all) fun start() {
            pre {
                self.state != BattleState.NotStarted: "Battle already started"
            }
            self.state = BattleState.InProgress
            // TODO: Implement battle start logic
        }

        access(all) fun resolve(domain: &{Domain}) {
            pre {
                self.state != BattleState.InProgress: "Battle not started"
                !self.randomnessFulfilled && getCurrentBlock().height > self.randomnessBlock: "Randomness not fulfilled yet"
            }
            self.randomnessFulfilled = true
            self.state = BattleState.Resolved
            // Record the battle result onchain.
            self.result = self.battleResult(turns: self.simulate(domain: domain))
        }
        
        access(all) fun battleResult(turns: [Turn]): BattleResult {
            pre {
                self.state == BattleState.Resolved: "Battle not resolved"
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

        access(all) fun simulate(domain: &{Domain}): [Turn] {
            pre {
                self.state == BattleState.Resolved: "Battle not resolved"
            }
            let seed = self._fulfillRandomness()
            //FIXME: Use real salt!!!
            let salt: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            let rng = Xorshift128plus.PRG(
                sourceOfRandomness: seed,
                salt: salt
            )
            let turns: [Turn] = [
                // The state prior to the first turn
                Turn(
                    myGold: 10,
                    myHearts: 3,
                    myRibbons: 0,
                    myTeam: self.myTeam,
                    theirGold: 10,
                    theirHearts: 3,
                    theirRibbons: 0,
                    theirTeam: self.theirTeam
                )
            ]
            while (false) {
                let turn: Turn = turns[turns.length - 1].next()
                for entity in self.myTeam {
                    if let entityRef: &{Entity} = domain.borrowEntity(id: entity) {
                        let applied = entityRef.applyEffects(battle: &self as &Battle, turn: &turn as &Turn)
                        if applied {
                            break
                        }
                    }
                }
                for entity in self.theirTeam {
                    if let entityRef: &{Entity} = domain.borrowEntity(id: entity) {
                        let applied = entityRef.applyEffects(battle: &self as &Battle, turn: &turn as &Turn)
                        if applied {
                            break
                        }
                    }
                }
                turns.append(turn)
            }
            return turns
        }

        access(contract) fun _fulfillRandomness(): [UInt8] {
            pre {
                !self.randomnessFulfilled:
                "RandomConsumer.Request.fulfill(): The random request has already been fulfilled."
                self.randomnessBlock < getCurrentBlock().height:
                "RandomConsumer.Request.fulfill(): Cannot fulfill random request before the eligible block height of "
                .concat((self.randomnessBlock + 1).toString())
            }
            self.randomnessFulfilled = true
            let res = RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value

            return res
        }
    }
    
    // -----------------------------------------------------------
    // RUN INTERFACE
    // -----------------------------------------------------------

    access(all) resource interface Run {
        access(all) event ResourceDestroyed(id: UInt64 = self.id)

        access(all) let id: UInt64
        access(all) let domainId: UInt64
        access(all) var isActive: Bool
        access(all) var battles: [Battle]
    }

    // -----------------------------------------------------------
    // STANDARD RUN RESOURCE
    // -----------------------------------------------------------

    access(all) resource StandardRun: Run {
        access(all) let id: UInt64
        access(all) let domainId: UInt64
        access(all) var isActive: Bool
        access(all) var battles: [Battle]

        init(domainId: UInt64) {
            self.id = self.uuid
            self.domainId = domainId
            self.isActive = false
            self.battles = []
            
            emit RunCreated(id: self.id, domainId: self.domainId)
        }

        access(all) fun start() {
            pre {
                !self.isActive: "Run is already active"
            }
            self.isActive = true
        }

        access(all) fun addBattle(myTeam: [UInt64], theirTeam: [UInt64]) {
            pre {
                self.isActive: "Run must be active to add battles"
            }
            self.battles.append(Battle(myTeam: myTeam, theirTeam: theirTeam))
        }

        access(all) fun getBattle(index: Int): Battle? {
            if index < self.battles.length {
                return self.battles[index]
            }
            return nil
        }

        access(all) fun getCurrentBattle(): Battle? {
            if self.battles.length == 0 {
                return nil
            }
            return self.battles[self.battles.length - 1]
        }
    }

    // -----------------------------------------------------------
    // RUN COLLECTION
    // -----------------------------------------------------------

    access(all) resource RunCollection {
        // Dictionary to store runs
        access(all) var runs: @{UInt64: {Run}}

        init () {
            self.runs <- {}
        }

        // Add a new run to the collection
        access(all) fun addRun(run: @{Run}) {
            let id = run.id
            self.runs[id] <-! run
        }

        // Get a reference to a run by ID
        access(all) fun borrowRun(id: UInt64): &{Run} {
            if let run: &{Run} = &self.runs[id] {
                return run
            } else {
                panic("Run not found")
            }
        }

        // Remove a run from the collection
        access(all) fun removeRun(id: UInt64): @{Run} {
            let run <- self.runs.remove(key: id) ?? panic("Run not found")
            return <- run
        }

        // Get all run IDs in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.runs.keys
        }

        // Get the number of runs in the collection
        access(all) view fun getLength(): Int {
            return self.runs.length
        }
    }

    // -----------------------------------------------------------
    // SEASON INTERFACE
    // -----------------------------------------------------------

    access(all) resource interface Domain {
        access(all) event ResourceDestroyed(id: UInt64 = self.id)

        access(all) let id: UInt64
        access(all) var entities: [UInt64]
        access(all) var runs: @{UInt64: {Run}}

        access(all) fun start(payment: @FlowToken.Vault)
        access(all) fun createRun(): @{Run}
        access(all) fun depositRun(run: @{Run})
        access(all) fun withdrawRun(id: UInt64): @{Run}
        access(all) fun borrowRun(id: UInt64): &{Run}
        access(all) fun borrowEntity(id: UInt64): &{Entity}?

        access(all) fun domainId(): UInt64 { return self.id }
    }

    // -----------------------------------------------------------
    // SEASON RESOURCE
    // -----------------------------------------------------------

    access(all) resource StandardDomain: Domain {
        access(all) event ResourceDestroyed(id: UInt64 = self.id)
        
        access(all) let id: UInt64
        access(all) var entities: [UInt64]
        access(all) var runs: @{UInt64: {Run}}

        init(entities: [UInt64]) {
            self.id = self.uuid
            self.entities = entities
            self.runs <- {}
            emit DomainCreated(id: self.id)
        }

        access(all) fun start(payment: @FlowToken.Vault) {
            let balance = payment.balance
            destroy payment
            
            emit DomainStarted(id: self.id, payment: balance)
        }

        access(all) fun createRun(): @{Run} {
            return <- create StandardRun(domainId: self.id)
        }

        access(all) fun depositRun(run: @{Run}) {
            pre {
                run.domainId == self.id: "Run does not belong to this domain"
            }
            let id = run.id
            self.runs[id] <-! run
        }

        access(all) fun withdrawRun(id: UInt64): @{Run} {
            let run <- self.runs.remove(key: id) ?? panic("Run not found")
            return <- run
        }

        access(all) fun borrowRun(id: UInt64): &{Run} {
            if let run: &{Run} = &self.runs[id] {
                return run
            } else {
                panic("Run not found")
            }
        }

        access(all) fun borrowEntity(id: UInt64): &{Entity}? {
            return nil
        }

        access(all) fun getEntityCount(): Int {
            return self.entities.length
        }
    }

    // -----------------------------------------------------------
    // SEASON COLLECTION
    // -----------------------------------------------------------

    access(all) resource DomainCollection {
        // Dictionary to store domains
        access(all) var domains: @{UInt64: {Domain}}

        init () {
            self.domains <- {}
        }

        // Add a new domain to the collection
        access(all) fun addDomain(domain: @{Domain}) {
            let id = domain.id
            self.domains[id] <-! domain
        }

        // Get a reference to a domain by ID
        access(all) fun borrowDomain(id: UInt64): &{Domain} {
            if let domain: &{Domain} = &self.domains[id] {
                return domain
            } else {
                panic("Domain not found")
            }
        }

        // Remove a domain from the collection
        access(all) fun removeDomain(id: UInt64): @{Domain} {
            let domain <- self.domains.remove(key: id) ?? panic("Domain not found")
            return <- domain
        }

        // Get all domain IDs in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.domains.keys
        }

        // Get the number of domains in the collection
        access(all) view fun getLength(): Int {
            return self.domains.length
        }
    }

    // -----------------------------------------------------------
    // PUBLIC FUNCTIONS
    // -----------------------------------------------------------

    access(all) fun createStandardEntity(name: String, url: String): @{Entity} {
        let entity <- create StandardEntity(name: name, url: url)
        return <- entity
    }

    access(all) fun createStandardDomain(entities: [UInt64]): @{Domain} {
        let domain <- create StandardDomain(entities: entities)
        return <- domain
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

    access(all) fun createEmptyEntityCollection(): @EntityCollection {
        let collection <- create EntityCollection()
        emit EntityCollectionCreated(owner: self.account.address)
        return <- collection
    }

    // -----------------------------------------------------------
    // CONTRACT INITIALIZER
    // -----------------------------------------------------------

    init() {
        self.DomainCollectionStoragePath = StoragePath(identifier: "domainCollectionStorage")!
        self.DomainCollectionPublicPath = PublicPath(identifier: "domainCollectionPublic")!

        self.RunCollectionStoragePath = StoragePath(identifier: "runCollectionStorage")!
        self.RunCollectionPublicPath = PublicPath(identifier: "runCollectionPublic")!

        self.EntityCollectionStoragePath = StoragePath(identifier: "entityCollectionStorage")!
        self.EntityCollectionPublicPath = PublicPath(identifier: "entityCollectionPublic")!
    }
}