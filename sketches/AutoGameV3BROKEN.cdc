import "RandomBeaconHistory"

access(all) contract AutoGame {


    //--------------------------------------------------------------------
    // TOY PRNG
    //--------------------------------------------------------------------

    // Crypto isn't working atm??? So this:

    // https://en.wikipedia.org/wiki/Xorshift
    access(all) struct Xorshift64 {
        access(all) var state: UInt64

        init(seed: UInt64, salt: UInt64) {
            self.state = seed ^ salt
        }

        access(all) fun nextInt(): UInt64 {
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

    access(all) struct interface Component {}

    //--------------------------------------------------------------------
    // ENTITIES
    //--------------------------------------------------------------------

    // An entity in the game with an identity and some Components.
    // All the data is in Components, they are updated by Systems.

    access(all) var entityCount: UInt64

    access(all) struct GameEntity {
        access(all) let id:         UInt64
        // Dictionary of component types to component data.
        // We use a dictionary rather than an array
        // for efficiency, and we use types rather than
        // ids or another scheme to ensure robustness.
        access(self) var components: {Type: {Component}}

        init(components: {Type: {Component}}) {
            AutoGame.entityCount = AutoGame.entityCount + 1
            self.id = AutoGame.entityCount
            self.components = components
        }

        access(all) fun listComponents(): [Type] {
            return self.components.keys
        }

        access(all) fun accessComponent(key: Type): &{Component} {
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
    // SYSTEM
    //--------------------------------------------------------------------

    // A System that updates Components on Entities in a Round via Effects.

    access(all) resource interface GameSystem {
        access(all) let id:          UInt64
        access(all) let metadataUrl: String

        // Apply initial state and prepare before-turn effects.
        access(all) fun addTurnBeforeEffects(turn: &GameTurn, prng: &Xorshift64)

        // Called each round before any effects have been applied, with a list of entities that have the Components the System is interested in.
        access(all) fun addRoundEffects(entities: &[GameEntity], round: &GameRound, prng: &Xorshift64)

        // Called each round after any effects have been applied, with a list of entities that have the Components the System is interested in.
        access(all) fun addRoundAfterEffects(entities: &[GameEntity], round: &GameRound, prng: &Xorshift64)

        // Apply after-turn effects and clean up.
        access(all) fun addTurnAfterEffects(turn: &GameTurn, prng: &Xorshift64)
    }

    //--------------------------------------------------------------------
    // EFFECT
    //--------------------------------------------------------------------

    // An Effect created by a System to be applied to a Round.
    // We create then apply so that we can apply simultaneously,
    // and so that in the absence of events we have a record of what happened.

    access(all) enum GameSystemEffectHint: UInt8 {
        access(all) case Attack
        access(all) case Faint
        access(all) case Recover
        access(all) case PowerUp
        access(all) case Substitution
    }

    access(all) struct interface GameSystemEffect {
        access(all) let hint: GameSystemEffectHint
        access(all) fun apply()
    }

    //--------------------------------------------------------------------
    // Physical Combat
    //--------------------------------------------------------------------

    // PhysicalCombat component for handling health and damage
    access(all) struct PhysicalCombatComponent: Component {
        access(all) var health: Int
        access(all) var damage: Int

        init(health: Int, damage: Int) {
            self.health = health
            self.damage = damage
        }

        access(all) fun changeHealth(_ health: Int) {
            self.health = self.health + health
        }

        access(all) fun changeDamage(_ damage: Int) {
            self.damage = self.damage + damage
        }
    }

        // Effect that applies damage during the combat phase
    access(all) struct PhysicalCombatDamageEffect: GameSystemEffect {
        access(all) let hint:    GameSystemEffectHint
        access(all) let entity: &GameEntity
        access(all) let damage:  Int

        init(entity: &GameEntity, damage: Int) {
            self.hint = GameSystemEffectHint.Attack
            self.entity = entity
            self.damage = damage
        }

        access(all) fun apply() {
             if let combat: &PhysicalCombatComponent = self.entity.accessComponent(key: Type<PhysicalCombatComponent>()) as? &PhysicalCombatComponent {
                combat.changeHealth(-combat.damage)
            }
        }
    }

// Effect that removes dead entities after combat
    access(all) struct PhysicalCombatFaintEffect: GameSystemEffect {
        access(all) let hint:      GameSystemEffectHint
        access(all) let entityID:  UInt64
        access(all) let round:    &GameRound

        init(entity: &GameEntity, round: &GameRound) {
            self.hint = GameSystemEffectHint.Faint
            self.entityID = entity.id
            self.round = round
        }

        access(all) fun apply() {
            self.round.removeEntity(id: self.entityID)
        }
    }

    // System that handles physical combat mechanics
    access(all) resource PhysicalCombatSystem: GameSystem {
        access(all) let id: UInt64
        access(all) let metadataUrl: String
        access(all) let componentType: Type

        init() {
            self.componentType = Type<PhysicalCombatComponent>()
            self.id = self.uuid
            self.metadataUrl = "blah"
        }

        access(all) fun addTurnBeforeEffects(turn: &GameTurn, prng: &Xorshift64) {
            // No before-turn effects needed
        }

        access(all) fun addTurnAfterEffects(turn: &GameTurn, prng: &Xorshift64) {
            // No after-turn effects needed
        }

        access(all) fun addRoundEffects(entities: &[GameEntity], round: &GameRound, prng: &Xorshift64) {
            // We only want the first entity from ourTeam and theirTeam,
            // and even then only if they are in our list of entities.
            // Apply damage to all entities with PhysicalCombatComponent.
            var effects: [{GameSystemEffect}] = []
            if round.myTeam.length > 0 && round.theirTeam.length > 0 {
                let myEntity = round.myTeam[0]
                let theirEntity = round.theirTeam[0]
                round.addDuringEffects([
                    PhysicalCombatDamageEffect(
                        entity: myEntity,
                        damage: (theirEntity.accessComponent(key: self.componentType) as! &PhysicalCombatComponent).damage
                    ),
                    PhysicalCombatDamageEffect(
                        entity: theirEntity,
                        damage: (myEntity.accessComponent(key: self.componentType) as! &PhysicalCombatComponent).damage
                    )
                ])
            }
        }
             
        access(all) fun addRoundAfterEffects(entities: &[GameEntity], round: &GameRound, prng: &Xorshift64) {
            //for entity in entities {
                let myEntity = round.myTeam[0]
                let theirEntity = round.theirTeam[0]
                //if let combat: &PhysicalCombatComponent = entity.accessComponent(key: self.componentType) as? &PhysicalCombatComponent {
                if (myEntity.accessComponent(key: self.componentType) as! &PhysicalCombatComponent).health <= 0 {
                        round.addAfterEffects([
                            PhysicalCombatFaintEffect(
                                entity: myEntity,
                                round: round    
                            )
                        ])
                    }
                if (theirEntity.accessComponent(key: self.componentType) as! &PhysicalCombatComponent).health <= 0 {
                        round.addAfterEffects([
                            PhysicalCombatFaintEffect(
                                entity: theirEntity,
                                round: round    
                            )
                        ])
                    }
                /*} else {
                    panic("entity has no PhysicalCombatComponent")
                }*/
            //}
        }
    }

    //--------------------------------------------------------------------
    // ROUND
    //--------------------------------------------------------------------

    // A Single update of the Turn state.

    access(all) struct GameRound {
        // The team states from the end of the previous Round,
        // before the Effects of the current Round are applied.
        // If this is the first Round, the team states are set from the
        // the Turn's initial team states.
        access(all) var myTeam:    [GameEntity]
        access(all) var theirTeam: [GameEntity]

        // Effects that should be applied and displayed before the
        // round's main events. Applied sequentially.
        access(all) var before:    [{GameSystemEffect}]

        // Effects that should be applied and displayed during the
        // round's main events. Applied simultaneously.
        access(all) var during:    [{GameSystemEffect}]

        // Effects that should be applied and displayed after the
        // round's main events. Applied sequentially.
        access(all) var after:     [{GameSystemEffect}]

        init(myTeam: [GameEntity], theirTeam: [GameEntity]) {
            self.myTeam = myTeam
            self.theirTeam = theirTeam
            self.before = []
            self.during = []
            self.after = []
        }

        access(all) fun addBeforeEffects(_ effects: [{GameSystemEffect}]) {
            self.before = self.before.concat(effects)
        }

        access(all) fun addDuringEffects(_ effects: [{GameSystemEffect}]) {
            self.during = self.during.concat(effects)
        }

        access(all) fun addAfterEffects(_ effects: [{GameSystemEffect}]) {
            self.after = self.after.concat(effects)
        }

        access(all) fun applyBeforeEffects() {
            for effect in self.before {
                effect.apply()
            }
        }

        access(all) fun applyDuringEffects() {
            for effect in self.during {
                effect.apply()
            }
        }

        access(all) fun applyAfterEffects() {
            for effect in self.after {
                effect.apply()
            }
        }

        //FIXME: this could be much more efficient
        access(all) fun removeEntity(id: UInt64) {
            let idFilter = view fun (element: GameEntity): Bool { return element.id == id }
            self.myTeam = self.myTeam.filter(idFilter)
            self.theirTeam = self.theirTeam.filter(idFilter)
        }
    }

    //--------------------------------------------------------------------
    // TURN
    //--------------------------------------------------------------------

    // A single battle in the Playthrough of a season.
    // The shop/workshop phase occurs implicitly in the Playthrough
    // between each Turn.

    access(all) enum GameTurnProgress: UInt8 {
        access(all) case Created
        access(all) case Resolved
    }

    access(all) enum GameTurnResult: UInt8 {
        access(all) case Undecided
        access(all) case Win
        access(all) case Lose
        access(all) case Draw
    }

    access(all) struct GameTurn {
        access(all) var progress: GameTurnProgress
        access(all) var result: GameTurnResult
        access(all) let randomnessBlock:     UInt64
        access(all) var randomnessFulfilled: Bool
        access(all) let myInitialTeam:             [GameEntity]
        access(all) var theirInitialTeam:          [GameEntity]

        //FIXME: get from the Season.
        access(all) let systems: [Capability<&{GameSystem}>]

        init(myTeam: [GameEntity], systems: [Capability<&{GameSystem}>]) {
            self.progress = GameTurnProgress.Created
            self.result = GameTurnResult.Undecided
            self.randomnessBlock = getCurrentBlock().height
            self.randomnessFulfilled = false
            self.myInitialTeam = myTeam
            self.theirInitialTeam = []
            self.systems = systems
        }

        access(all) fun battle(theirTeam: [GameEntity]): GameTurnResult {
            /*pre {
                !self.randomnessFulfilled:
                "RandomConsumer.Request.fulfill(): The random request has already been fulfilled."
                self.randomnessBlock < getCurrentBlock().height:
                "RandomConsumer.Request.fulfill(): Cannot fulfill random request before the eligible block height of "
                .concat((self.randomnessBlock + 1).toString())
                self.progress == GameTurnProgress.Created:
                "GameTurn.battle(): The game turn has already been resolved."
            }*/

            // TODO: apply pre-turn effects

            self.theirInitialTeam = theirTeam
            let rounds = self.simulate()

            self.progress = GameTurnProgress.Resolved
            self.result = self.determineResult(rounds: rounds)

            // TODO: Apply after-turn effects, e.g. permanent level-ups,

            return self.result
        }

        access(all) fun determineResult(rounds: [GameRound]): GameTurnResult {
            let last = rounds[rounds.length - 1]
            if last.myTeam.length == 0 || last.theirTeam.length == 0 {
                if last.myTeam.length == 0 && last.theirTeam.length == 0 {
                    return GameTurnResult.Draw
                } else if last.myTeam.length > 0 {
                    return GameTurnResult.Win
                } else if last.theirTeam.length > 0 {
                    return GameTurnResult.Lose
                }
            }
            return GameTurnResult.Undecided
        }

        access(all) fun simulate(): [GameRound] {
            var prng = self.prng()
            var initialState = GameRound(
                myTeam:    self.myInitialTeam,
                theirTeam: self.theirInitialTeam
            )

            for system in self.systems {
                system.borrow()!.addTurnBeforeEffects(turn: &self as &GameTurn, prng: &prng as &Xorshift64)
            }

            var rounds = [initialState]

            var it_is_so_on = true

            while it_is_so_on {
                // Copy the previous round entity states
                var round = GameRound(
                    myTeam: rounds[rounds.length - 1].myTeam,
                    theirTeam: rounds[rounds.length - 1].theirTeam
                )
                // Gather effects from systems
                for system in self.systems {
                    system.borrow()!.addRoundEffects(
                        entities: &round.myTeam.concat(round.theirTeam) as &[GameEntity],
                        round: &round as &GameRound,
                        prng: &prng as &Xorshift64
                    )
                }

                // Apply effects
                round.applyDuringEffects()

                // Gather after-effects from systems
                for system in self.systems {
                    system.borrow()!.addRoundAfterEffects(
                        entities: &(round.myTeam.concat(round.theirTeam)) as &[GameEntity],
                        round: &round as &GameRound,
                        prng: &prng as &Xorshift64
                    )
                }

                // Apply after-effects
                round.applyAfterEffects()

                if round.myTeam.length == 0 || round.theirTeam.length == 0 {
                    it_is_so_on = false
                    if round.myTeam.length == 0 && round.theirTeam.length == 0 {
                        self.result = GameTurnResult.Draw
                    } else if round.myTeam.length > 0 {
                        self.result = GameTurnResult.Win
                    } else if round.theirTeam.length > 0 {
                        self.result = GameTurnResult.Lose
                    }
                }
                rounds.append(round)
            }

            for system in self.systems {
                system.borrow()!.addTurnAfterEffects(turn: &self as &GameTurn, prng: &prng as &Xorshift64)
            }

            return rounds
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
            pre {
                !self.randomnessFulfilled:
                "RandomConsumer.Request.fulfill(): The random request has already been fulfilled."
                self.randomnessBlock < getCurrentBlock().height:
                "RandomConsumer.Request.fulfill(): Cannot fulfill random request before the eligible block height of "
                .concat((self.randomnessBlock + 1).toString())
            }
            self.randomnessFulfilled = true
            let res: [UInt8] = RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value

            return res
        }

    }

    //--------------------------------------------------------------------
    // PLAYTHROUGH
    //--------------------------------------------------------------------

    // A single play-through of a Season by a player.

    access(all) resource GamePlaythrough {
        // The current state of the entities, as of the end of the most recent
        // battle.
        // Their history is stored as the initial myTeam in each battle.
        // We don't need any more state onchain than that, as it's what we need
        // to replay the game and use the team as someone else's theirTeam.
        access(all) var entities: [GameEntity]

        access(all) var turns: [GameTurn]

        init() {
            self.entities = []
            self.turns = []
        }
    }

    //--------------------------------------------------------------------
    // SEASON
    //--------------------------------------------------------------------

    // A Season of the game.

    access(all) resource GameSeason {
        access(all) var systems: [Capability<&{GameSystem}>]

        init() {
            self.systems = []
        }
    }

    //--------------------------------------------------------------------
    // FOR TESTING/DEMONSTRATION ONLY
    //--------------------------------------------------------------------


    // Create Team A with 5 entities
    access(all) fun createTeamA(): [GameEntity] {
        let team: [GameEntity] = []
        
        // Tank with high health, low damage
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 3, damage: 1)
            }
        ))

        // DPS with medium health, high damage
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 2, damage: 3)
            }
        ))

        // Balanced fighter
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 2, damage: 2)
            }
        ))

        // Glass cannon with low health, very high damage
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 1, damage: 4)
            }
        ))

        // Support with high health, low damage
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 3, damage: 1)
            }
        ))

        return team
    }

    // Create Team B with 5 entities
    access(all) fun createTeamB(): [GameEntity] {
        let team: [GameEntity] = []
        
        // Balanced tank
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 2, damage: 2)
            }
        ))

        // Aggressive fighter
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 1, damage: 3)
            }
        ))

        // Defensive fighter
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 3, damage: 1)
            }
        ))

        // Balanced DPS
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 2, damage: 2)
            }
        ))

        // High-risk fighter
        team.append(GameEntity(
            components: {
                Type<PhysicalCombatComponent>(): PhysicalCombatComponent(health: 1, damage: 3)
            }
        ))

        return team
    }

    access(self) var systemCaps: [Capability<&{GameSystem}>]

    access(all) fun createATurn(): GameTurn {
        let myTeam = self.createTeamA()  
        let turn = GameTurn(
            myTeam: myTeam, 
            systems: AutoGame.systemCaps
        )
        return turn
    }

    access(all) fun playATurn(turn: &GameTurn): GameTurnResult {
        return turn.battle(theirTeam: AutoGame.createTeamB())
    }

    //--------------------------------------------------------------------
    // CONTRACT INIT
    //--------------------------------------------------------------------

    init() {
        self.entityCount = 0
        self.account.storage.save(<- create PhysicalCombatSystem(),  to: /storage/PhysicalCombatSystem)
        self.systemCaps = [
            self.account.capabilities.storage.issue<&{GameSystem}>(/storage/PhysicalCombatSystem)
        ]
    }

}