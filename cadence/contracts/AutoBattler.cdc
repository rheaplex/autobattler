import "RandomBeaconHistory"
import "FungibleToken"
import "FlowToken"

import "ToyPRNG"

access(all) contract AutoBattler {

    //--------------------------------------------------------------------
    // ECS
    //--------------------------------------------------------------------

    // We use ECS (Entity Component System architecture).

    // Entity
    // An entity is just a struct with an ID and a dictionary of components.
    // We use dictionaries rather than arrays as the cache-line advantage
    // of arrays is less applicable for Flow.

    // Component
    // A component is just a struct that stores state for a system.

    // System
    // A system is a resource that adds and updates components on entities,
    // and adds/filters actions within a Battle Turn.

    // Action
    // An action is a struct created by a System that modifies components
    // on entities when executed.

    // Season
    // A season is a resource that contains a set of entities and systems.

    // Team
    // A team is a list of entities, each with their state at the time the
    // team was created.

    // Playthrough
    // A playthrough is a resource that contains a player's state within 
    // a Season.
    // It is created when a player starts a Season.
    // It is updated when a player engages in a Battle.
    // It keeps a history of teams so that these can be matched to other
    // players for battles.
    // It keeps a history of battles, but not turns.
    // The playthrough continues until the player finishes or they achieve
    // a victory condition set by the Season, whichever comes first.
    // To play through a season, the player steps repeatedly through three
    // stages, Shop, Team Assembly, and Battle.

    //--------------------------------------------------------------------
    // PLAYTHROUGH STAGES
    //--------------------------------------------------------------------

    // SHOP STAGE

    // TEAM ASSEMBLY STAGE


    // BATTLE STAGE

    // Battle
    // A battle is a resource that contains a set of entities and systems.
    // It is created when a player engages in a Battle.
    // The player's team state is copied from the player's current team,
    // and cannot be updated in Battle.
    // The random seed for the Battle is committed to at this time as
    // well to avoid attacks enabled by knowledge of the seed.
    // The opponent's team state determined by the Season at the time
    // the Battle is run onchain. Its state is copied from the opponent's
    // Playthrough Team history for the same battle.
    // To calculate the outcome of the battle, the Battle resource
    // regenerates the initial state of the Battle and then enters a
    // game loop that processes each Turn in order.
    // The Battle keeps a record of its win/lose/draw state for the
    // player, but not turns, which can be regenerated from the
    // battle's initial state offchain.

    // Turn
    // A turn is merely a successive state of a Battle within the Battle's
    // game loop.
    //
    // It has successive phases that are processed in order:
    // - Buffs.
    //   A buff is an action that modifies the state of an Entity's Components
    //   before any attacks have taken place.
    // - Attacks.
    //   An attack is an action that resolves attack/defense/damage for
    //   an entity's components.
    // - Recoveries.
    //   A recovery is an action that heals an entity's components after
    //   attacks have taken place.
    // - Resolves.
    //   A resolve is an action that updates the Entity's components
    //   based on their state after the Attacks and Recoveries.
    //   This can add statuses like "Fainted", and queue removes.
    // - Removes.
    //   A remove is an action that removes an Entity from the Battle for the
    //   next Turn.
    //   This means that the state of play at the start of each turn
    //   can be taken from the state of the teams, and the state for
    //   the next turn can be calculated by applying the listed actions.
    //
    // Each phase has an add, filter, and apply phase in which all
    // the Systems get to act in turn:
    // - The add phase adds actions to the turn.
    // - The filter phase filters actions from the turn, allowing each
    //   system to review, modify, or remove them.
    // - The apply phase perform()s actions, which may modify the state of
    //   each Entity's Components in each Team in the battle and,
    //   in the case of the Resolve phase, queue Removes.

    //--------------------------------------------------------------------
    // COMPONENTS
    //--------------------------------------------------------------------

    // The data for a Component.
    // Used instead of AnyStruct so we can check types usefully,
    // and add features if needed.

    access(all) struct interface Component {
        access(all) fun copy(): {Component}
    }

    // Health, aura, speed, magic, luck

    access(all) struct interface Attribute: Component {
        access(all) var value: Int8

        access(all) fun set(to: Int8)
    }

    // Damage, heal, slow, speed-up, burn, drain, boost

    access(all) struct interface Ability : Component {
        access(all) let affectsAttribute: Type
        access(all) var amount:           Int8
    }

    //--------------------------------------------------------------------
    // ENTITIES
    //--------------------------------------------------------------------

    // An entity in the game with an identity and some Components.
    // All the data is in Components, they are updated by Systems.

    access(contract) var entityCount:      UInt64

    access(all) struct Entity {
        access(all) let id:           UInt64
        // Dictionary of component types to component data.
        // We use a dictionary rather than an array
        // for efficiency, and we use types rather than
        // ids or another scheme to ensure robustness.
        access(self) var components: {Type: {Component}}

        init(components: {Type: {Component}}, _ id: UInt64?) {
            AutoBattler.entityCount = AutoBattler.entityCount + 1
            self.id = id ?? AutoBattler.entityCount
            self.components = components
        }

        access(all) fun copy(): Entity {
            let components: {Type: {Component}} = {}
            for key in self.components.keys {
                components[key] = self.components[key]!.copy()
            }
            return Entity(components: components, self.id)
        }

        access(all) fun listComponents(): [Type] {
            return self.components.keys
        }

        access(all) fun accessComponent(_ key: Type): &{Component} {
            return &self.components[key]!
        }

        access(all) fun attachComponent(key: Type, value: {Component}) {
            self.components[key] = value
        }

        access(all) fun detachComponent(key: Type): {Component} {
            return self.components.remove(key: key)!
        }
    }

    //--------------------------------------------------------------------
    // ACTION
    //--------------------------------------------------------------------

    access(all) struct interface Action {
        access(all) fun perform()
        // This is for development only.
        access(all) fun toString(): String
    }

    //--------------------------------------------------------------------
    // TURN
    //--------------------------------------------------------------------

    access(all) struct Turn {
        // The team states from the end of the previous Turn,
        // before the Actions of the current Turn are applied.
        // If this is the first Turn, the team states are set from the
        // the Turn's initial team states.
        access(contract) var myTeam:     [Entity]
        access(contract) var theirTeam:  [Entity]
        access(contract) var removes:    [UInt64]

        access(self) var     buffs:      [{Action}]
        access(self) var     attacks:    [{Action}]
        access(self) var     recoveries: [{Action}]
        access(self) var    resolves:   [{Action}]

        init(myTeam: [Entity], theirTeam: [Entity]) {
            self.myTeam = myTeam
            self.theirTeam = theirTeam
            self.buffs = []
            self.attacks = []
            self.recoveries = []
            self.resolves = []
            self.removes = []
        }

        access(all) fun toString(): String {
            var str = "Mine: ["
            .concat(
                String.join(
                    self.myTeam.map<String>(fun (e: Entity): String { return e.id.toString() }),
                    separator: ", "
                )
            )
            .concat("], Theirs: [")
            .concat(
                String.join(
                    self.theirTeam.map<String>(fun (e: Entity): String { return e.id.toString() }),
                    separator: ", "
                )
            )
            .concat("] ")

            if self.buffs.length > 0 {
                str = str.concat("Buffs: [{")
                .concat(
                    String.join(
                        self.buffs.map<String>(fun (a: {Action}): String { return a.toString() }),
                        separator: "}, {"
                    )
                )
                .concat("}] ")
            }

            if self.attacks.length > 0 {
                str = str.concat("Attacks: [{")
                .concat(
                    String.join(
                        self.attacks.map<String>(fun (a: {Action}): String { return a.toString() }),
                        separator: "}, {"
                    )
                )
                .concat("}] ")
            }

            if self.recoveries.length > 0 {
                str = str.concat("Recoveries: [{")
                .concat(
                    String.join(
                        self.recoveries.map<String>(fun (a: {Action}): String { return a.toString() }),
                        separator: "}, {"
                    )
                )
                .concat("}] ")
            }

            if self.resolves.length > 0 {
                str = str.concat("Resolves: [{")
                .concat(
                    String.join(
                        self.resolves.map<String>(fun (a: {Action}): String { return a.toString() }),
                        separator: "}, {"
                    )
                )
                .concat("}] ")
            }

            return str
        }

        access(all) fun copy(): Turn {
            var myNewTeam: [Entity] = []
            for my in self.myTeam {
                if ! self.removes.contains(my.id) {
                    myNewTeam.append(my.copy())
                }
            }
            var theirNewTeam: [Entity] = []
            for their in self.theirTeam {
                if ! self.removes.contains(their.id) {
                    theirNewTeam.append(their.copy())
                }
            }
            return Turn(myTeam: myNewTeam, theirTeam: theirNewTeam)
        }

        access(all) fun addBuff(_ action: {Action}) {
            self.buffs.append(action)
        }

        access(all) fun applyBuffs() {
            for buff in self.buffs {
                buff.perform()
            }
        }

        access(all) fun addAttack(_ action: {Action}) {
            self.attacks.append(action)
        }

        access(all) fun applyAttacks() {
            for attack in self.attacks {
                attack.perform()
            }
        }

        access(all) fun addRecovery(_ action: {Action}) {
            self.recoveries.append(action)
        }

        access(all) fun applyRecovers() {
            for recovery in self.recoveries {
                recovery.perform()
            }
        }

        access(all) fun addResolve(_ action: {Action}) {
            self.resolves.append(action)
        }

        access(all) fun applyResolves() {
            for resolve in self.resolves {
                resolve.perform()
            }
        }

        access(all) fun addRemove(id: UInt64) {
            self.removes.append(id)
        }
    }

    //--------------------------------------------------------------------
    // BATTLE
    //--------------------------------------------------------------------

    access(all) enum BattleResult: UInt8 {
        access(all) case Undecided
        access(all) case Win
        access(all) case Lose
        access(all) case Draw
    }

    access(all) event BattleResolved(result: UInt8)

    access(all) struct Battle {
        access(all) var result:                 BattleResult
        access(self) let randomnessBlock:       UInt64
        access(self) var randomnessFulfilled:   Bool
        access(contract) let myInitialTeam:    [Entity]
        access(contract) var theirInitialTeam: [Entity]
        //FIXME: get from the Season.
        access(self) let systems:              [Capability<&{System}>]

        init(myTeam: [Entity], systems: [Capability<&{System}>]) {
            self.result = BattleResult.Undecided
            self.randomnessBlock = getCurrentBlock().height
            self.randomnessFulfilled = false
            self.myInitialTeam = myTeam
            self.systems = systems
            self.theirInitialTeam = []
        }

        access(all) fun battle(_ theirTeam: [Entity]): BattleResult {
            self.theirInitialTeam = theirTeam
            let turns = self.simulate()
            self.result = self.determineResult(turns: turns)
            for system in self.systems {
                system.borrow()!.afterBattle(battle: &self as &Battle)
            }
            emit BattleResolved(result: self.result.rawValue)
            return self.result
        }

        access(all) fun simulate(): [Turn] {
            var prng = self.prng()
            var turns = [Turn(
                myTeam:    self.myInitialTeam,
                theirTeam: self.theirInitialTeam
            )]
            while true {
                var turn = turns[turns.length - 1].copy()

                if turn.myTeam.length == 0 || turn.theirTeam.length == 0 {
                    turns.append(turn)
                    break
                }

                for system in self.systems {
                    system.borrow()!.addBuffs(&turn as &Turn)
                }
                for system in self.systems {
                    system.borrow()!.filterBuffs(&turn as &Turn)
                }
                turn.applyBuffs()

                for system in self.systems {
                    system.borrow()!.addAttacks(&turn as &Turn)
                }
                for system in self.systems {
                    system.borrow()!.filterAttacks(&turn as &Turn)
                }
                turn.applyAttacks()

                for system in self.systems {
                    system.borrow()!.addRecovers(&turn as &Turn)
                }
                for system in self.systems {
                    system.borrow()!.filterRecovers(&turn as &Turn)
                }
                turn.applyRecovers()

                for system in self.systems {
                    system.borrow()!.addResolves(&turn as &Turn)
                }
                for system in self.systems {
                    system.borrow()!.filterResolves(&turn as &Turn)
                }
                turn.applyResolves()
                
                turns.append(turn)
            }
            return turns
        }

        access(all) fun determineResult(turns: [Turn]): BattleResult {
            let last = turns[turns.length - 1]
            if last.myTeam.length == 0 || last.theirTeam.length == 0 {
                if last.myTeam.length == 0 && last.theirTeam.length == 0 {
                    return BattleResult.Draw
                } else if last.myTeam.length > 0 {
                    return BattleResult.Win
                } else if last.theirTeam.length > 0 {
                    return BattleResult.Lose
                }
            }
            return BattleResult.Undecided
        }

        access(all) fun prng(): ToyPRNG.Xorshift64 {
            //FIXME: Use real salt!!!
            let entropy: [UInt8] = self._fulfillRandomness()
            let salt: UInt64 = 112123123412345
            return ToyPRNG.Xorshift64(
                seed: UInt64.fromBigEndianBytes(entropy.slice(from: 0, upTo: 8))!,
                salt: salt
            )
        }

        access(contract) fun _fulfillRandomness(): [UInt8] {
            self.randomnessFulfilled = true
            return RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value
        }
    }

    //--------------------------------------------------------------------
    // SYSTEM
    //--------------------------------------------------------------------

    // A System that updates Components on Entities in phases of a Turn
    // in a Round via Actions.

    access(all) resource interface System {
        access(contract) var url: String

        //FIXME: Name this better. Called to set up an entity for
        //       a PlayThrough.
        access(all) fun initializeEntity(_ entity: &Entity)

        // This is called *once* to modify onchain state after a battle
        // has been battle()d.
        access(all) fun afterBattle(battle: &Battle)

        access(all) fun addBuffs(_ turn: &Turn)
        access(all) fun filterBuffs(_ turn: &Turn)
        access(all) fun addAttacks(_ turn: &Turn)
        access(all) fun filterAttacks(_ turn: &Turn)
        access(all) fun addRecovers(_ turn: &Turn)
        access(all) fun filterRecovers(_ turn: &Turn)
        access(all) fun addResolves(_ turn: &Turn)
        access(all) fun filterResolves(_ turn: &Turn)
    }

    //--------------------------------------------------------------------
    // THE BASIC HEALTH/DAMAGE SYSTEM
    //--------------------------------------------------------------------

    access(all) struct Health: Attribute {
        access(all) var value: Int8

        init(value: Int8) {
            self.value = value
        }

        access(all) fun set(to: Int8) {
            self.value = to
        }

        access(all) fun copy(): {Component} {
            return Health(value: self.value)
        }
    }

    access(all) struct Damage: Ability {
        access(all) let affectsAttribute: Type
        access(all) var amount: Int8

        init(amount: Int8) {
            self.affectsAttribute = Type<Health>()
            self.amount = amount
        }

        access(all) fun copy(): {Component} {
            return Damage(amount: self.amount)
        }
    }

    // Applies damage during the combat phase
    access(all) struct Attack: Action {
        access(all) let attacker: &Entity
        access(all) let defender: &Entity

        init(attacker: &Entity, defender: &Entity) {
            self.attacker = attacker
            self.defender = defender
        }

        //! Defender should get to have a say. e.g. if defender has defendAttack() method, it should be called.
        //! Subject defines verb, verb & subject go to object and ask it if it can handle them or should we do the default.
        // 
        access(all) fun perform() {
            let defenderHealth: &AutoBattler.Health = self.defender.accessComponent(Type<Health>()) as! &Health
            let attackerDamage: &AutoBattler.Damage = self.attacker.accessComponent(Type<Damage>()) as! &Damage
            let preHealth = defenderHealth.value
            defenderHealth.set(to: preHealth - attackerDamage.amount)
        }

        access(all) fun toString(): String {
            return "Attack. Attacker: ".concat(self.attacker.id.toString())
                .concat(", Defender: ".concat(self.defender.id.toString()))
                .concat(", Damage: ".concat((self.attacker.accessComponent(Type<Damage>()) as! &Damage).amount.toString()))
                .concat(", Health: ".concat((self.defender.accessComponent(Type<Health>()) as! &Health).value.toString()))
        }
    }

    // Removes fainted entities
    access(all) struct Faint: Action {
        access(all) let entity: &Entity
        access(all) let turn: &Turn

        init(entity: &Entity, turn: &Turn) {
            self.entity = entity
            self.turn = turn
        }

        access(all) fun perform() {
            let entityID = self.entity.id
            self.turn.addRemove(id: entityID)
        }

        access(all) fun toString(): String {
            return "Faint. Entity: ".concat(self.entity.id.toString())
        }
    }

    access(all) resource DamageSystem: System {
        access(contract) var url: String

        init(url: String) {
            self.url = url
        }

        access(all) fun initializeEntity(_ entity: &Entity) {}
        access(all) fun afterBattle(battle: &Battle) {}

        access(all) fun addBuffs(_ turn: &Turn) {}
        access(all) fun filterBuffs(_ turn: &Turn) {}

        access(all) fun addAttacks(_ turn: &Turn) {
            let myEntity = turn.myTeam[0]
            let opponentEntity = turn.theirTeam[0]
            turn.addAttack(Attack(attacker: myEntity, defender: opponentEntity))
            turn.addAttack(Attack(attacker: opponentEntity, defender: myEntity))
        }
        
        access(all) fun filterAttacks(_ turn: &Turn) {}
        access(all) fun addRecovers(_ turn: &Turn) {}
        access(all) fun filterRecovers(_ turn: &Turn) {}

        access(all) fun addResolves(_ turn: &Turn) {
            let myEntity = turn.myTeam[0]
            if (myEntity.accessComponent(Type<Health>()) as! &Health).value <= 0 {
                turn.addResolve(Faint(entity: myEntity, turn: turn))
            }
            let theirEntity = turn.theirTeam[0]
            if (theirEntity.accessComponent(Type<Health>()) as! &Health).value <= 0 {
                turn.addResolve(Faint(entity: theirEntity, turn: turn))
            }
        }

        access(all) fun filterResolves(_ turn: &Turn) {}
    }

    //--------------------------------------------------------------------
    // PLAYTHROUGH
    //--------------------------------------------------------------------

    access(all) enum PlaythroughStage: UInt8 {
        access(all) case Store
        access(all) case Battle
    }

    access(all) resource Playthrough {
        access(all) let season: Capability<&{AutoBattler.Season}>
        access(all) let entities: {UInt64: Entity}
        access(all) let myTeam: [UInt64]
        access(all) var battles: [Battle]
        access(all) var coins: UInt64
        access(all) var stage: PlaythroughStage

        init(season: Capability<&{AutoBattler.Season}>) {
            self.season = season
            self.entities = {}
            self.myTeam = []
            self.battles = []
            self.coins = 0
            self.stage = PlaythroughStage.Store
        }

        access(contract) fun setStage(_ stage: PlaythroughStage) {
            self.stage = stage
        }

        access(contract) fun setCoins(_ coins: UInt64) {
            self.coins = coins
        }

        access(contract) fun addPurchasedEntity(_ entity: Entity) {
            self.entities[entity.id] = entity
        }

        access(contract) fun addEntityToTeam (id: UInt64, index: Int) {
            pre {
                self.stage == PlaythroughStage.Store
                index >= 0
                self.entities.keys.contains(id)
                self.myTeam.length <= index
                ! self.myTeam.contains(id)
            }
            if index == self.myTeam.length {
                self.myTeam.append(id)
            } else {
                // This shifts existing elements rather than overwriting.
                self.myTeam.insert(at: index, id)
            }
        }

        access(all) fun removeEntityFromTeam (index: Int) {
            pre { self.stage == PlaythroughStage.Store }
            let _ = self.myTeam.remove(at: index)
        }

        access(contract) fun newBattle(systems: [Capability<&{AutoBattler.System}>]) {
            pre { self.stage == PlaythroughStage.Store }
            self.stage = PlaythroughStage.Battle
            let team: [Entity] = []
            for id in self.myTeam {
                team.append(self.entities[id]!.copy())
            }
            self.battles.append(Battle(myTeam: team, systems: systems))
        }
            
    }

    //--------------------------------------------------------------------
    // Season
    //--------------------------------------------------------------------

    access(all) struct StoreEntity {
        access(all) let entity: Entity
        access(all) let price: UInt64

        init(entity: Entity, price: UInt64) {
            self.entity = entity
            self.price = price
        }
    }

    access(all) resource interface Season {
        access(contract) var url: String
        access(all) let currencyName: String
        access(all) let currencySymbol: String
        access(all) var currencyPerStorePhase: UInt64
        access(all) var systems: [Capability<&{AutoBattler.System}>]
        access(all) var playthroughPrice: UFix64

        access(all) fun getEntityIds(): [UInt64]
        access(all) fun getEntityPrice(id: UInt64): UInt64
        access(all) fun purchaseEntity(playthrough: &Playthrough, id: UInt64)

        access(contract) fun purchaseSeasonPlaythrough (payment: @{FungibleToken.Vault}): @Playthrough

        access(contract) fun startBattle(playthrough: &Playthrough)
        access(contract) fun endBattle(playthrough: &Playthrough)
    }

    access(all) resource StandardSeason: Season {
        access(contract) var url: String
        access(all) let currencyName: String
        access(all) let currencySymbol: String
        access(all) var currencyPerStorePhase: UInt64
        access(all) var systems: [Capability<&{AutoBattler.System}>]
        access(all) var entities: {UInt64: StoreEntity}
        access(all) var playthroughPrice: UFix64

        init(url: String, currencyName: String, currencySymbol: String, currencyPerStorePhase: UInt64, playthroughPrice: UFix64) {
            self.url = url
            self.currencyName = currencyName
            self.currencySymbol = currencySymbol
            self.systems = []
            self.entities = {}
            self.currencyPerStorePhase = currencyPerStorePhase
            self.playthroughPrice = playthroughPrice
        }

        access(all) fun addSystem(_ system: Capability<&{AutoBattler.System}>) {
            self.systems.append(system)
        }

        access(all) fun addEntity(_ entity: Entity, price: UInt64) {
            self.entities[entity.id] = StoreEntity(entity: entity, price: price)
        }

        access(all) fun getEntityIds(): [UInt64] {
            return self.entities.keys
        }

        access(all) fun getEntityPrice(id: UInt64): UInt64 {
            return self.entities[id]!.price
        }

        /*access(all) fun getEntityURL(id: UInt64): String {
            return self.entities[id]!.entity.accessComponent(Type<AutoBattler.Entity>()) as! &AutoBattler.Entity
        } */

        access(all) fun purchaseEntity(playthrough: &Playthrough, id: UInt64) {
            pre {
                playthrough.stage == PlaythroughStage.Store
            }
            playthrough.setCoins(playthrough.coins - self.entities[id]!.price)
            playthrough.addPurchasedEntity(self.entities[id]!.entity.copy())
        }

        access(contract) fun purchaseSeasonPlaythrough (payment: @{FungibleToken.Vault}): @Playthrough {
            pre { 
                payment.balance == self.playthroughPrice
            }
            let vault <- payment as! @FlowToken.Vault
            /////FIXME!!!!!! Deposit!!!!!!!!
            destroy vault
            /////FIXME: CAPABILITY!!!!!!!!
            //          one per playthrough, or one for all?
            return <-create Playthrough(self as Capability<&{AutoBattler.Season}>)
        }

        access(contract) fun startBattle(playthrough: &Playthrough) {
            pre { playthrough.stage == PlaythroughStage.Store }

            playthrough.newBattle(systems: self.systems)
        }

        access(contract) fun endBattle(playthrough: &Playthrough) {
            pre { playthrough.stage == PlaythroughStage.Battle }

            let battle = playthrough.battles[playthrough.battles.length - 1]
            // FIXME: CHOOSE AN OPPOSING TEAM.
            let theirTeam = AutoBattler.randomTeam()
            let _ = battle.battle(theirTeam)
            // These should go in the playthrough.
            playthrough.setStage(PlaythroughStage.Store)
            playthrough.setCoins(self.currencyPerStorePhase)
        }
    }

    //--------------------------------------------------------------------
    // Testing
    //--------------------------------------------------------------------

    access(all) fun randomEntity() : Entity {
        let h = Int8(1 as UInt8 + revertibleRandom<UInt8>(modulo: 4))
        let health = Health(value: h)
        let d = Int8(1 as UInt8 + revertibleRandom<UInt8>(modulo: 2))
        let damage = Damage(amount: d)
        return Entity(components: {
            Type<Health>(): health,
            Type<Damage>(): damage
        }, nil)
    }

    access(all) fun randomTeam() : [Entity] {
        return [
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity()
        ]
    }

    access(all) fun runOneBattle() : Battle {
        let ourTeam = AutoBattler.randomTeam()
        let theirTeam = AutoBattler.randomTeam()

        let systems: [Capability<&{AutoBattler.System}>] = [
            self.account.capabilities.get<&{AutoBattler.System}>(/public/battleSystem)
        ]

        let battle = Battle(myTeam: ourTeam, systems: systems)

        battle.battle(theirTeam)

        return battle
    }

    //--------------------------------------------------------------------
    // CONTRACT INITIALIZER
    //--------------------------------------------------------------------

    init () {
        self.entityCount = 0
        let battleSystem <- create AutoBattler.DamageSystem(url: "ipfs://blah/")
        self.account.storage.save(<- battleSystem, to: /storage/battleSystem)
        let battleSystemCapability = self.account.capabilities.storage.issue<&{AutoBattler.System}>(/storage/battleSystem)
        self.account.capabilities.publish(battleSystemCapability, at: /public/battleSystem)
    }
}