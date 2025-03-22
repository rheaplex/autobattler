import "RandomBeaconHistory"

access(all) contract AutoBattler {

    //--------------------------------------------------------------------
    // TOY PRNG
    //--------------------------------------------------------------------

    // DO NOT USE THIS IN PRODUCTION

    // https://en.wikipedia.org/wiki/Xorshift
    access(all) struct Xorshift64 {
        access(self) var state: UInt64

        init(seed: UInt64, salt: UInt64) {
            self.state = seed ^ salt
        }

        access(contract) fun nextUInt64(): UInt64 {
            var x = self.state
            x = x ^ (x << 13)
            x = x ^ (x >> 7)
            x = x ^ (x << 17)
            self.state = x
            return x
        }
    }

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

        access(self) var buffs:      [{Action}]
        access(self) var attacks:    [{Action}]
        access(self) var recoveries: [{Action}]
        access(self) var resolves:   [{Action}]

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

        access(all) fun prng(): Xorshift64 {
            //FIXME: Use real salt!!!
            let entropy: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8] //self._fulfillRandomness()
            let salt: UInt64 = 112123123412345
            return Xorshift64(
                seed: UInt64.fromBigEndianBytes(entropy.slice(from: 0, upTo: 8))!,
                salt: salt
            )
        }

        access(contract) fun _fulfillRandomness(): [UInt8] {
            self.randomnessFulfilled = true
            ////let res: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
             //RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value
            return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
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

    access(all) fun runOneBattle() : Battle {
        let ourTeam = [
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity()
        ]

        let theirTeam = [
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity(),
            AutoBattler.randomEntity()
        ]

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