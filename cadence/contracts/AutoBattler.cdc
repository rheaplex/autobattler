import "FungibleToken"
import "FlowToken"
import "RandomBeaconHistory"

import "ToyPRNG"

/*
 * IMPORTANT NOTE: DO NOT USE IN PRODUCTION!
 *
 * This is a work in progress. It compiles, its tests run, and it demonstrates the approach that it is designed to.
 *
 * BUT:
 * - Access levels and access strategies have varied as they have been explored and have not yet been regularized.
 * - The same is true of degrees of indirection, and of distribution of responsibilities between types.
 * - Most obviously, the Season (and SeasonProxy) logic is unfinished.
 * - As a result, the code has not been debugged or audited.
 */

access(all) contract AutoBattler {

    /* Design
     * ======
     *
     * Principles
     * ----------
     *
     * - Everything that is an ownable asset should be a resource, but not everything that is a resource is an ownable asset.
     * - Ownership of a resource does not imply ownership of the underlying asset, or complete control over it. In particular,
         resources within a Pass are not directly exposed to the owner of the Pass, but rather managed by the Season and its Systems.
     * - Encapsulation of capabilities is better than exposing them directly.
     * - Flexible and extensible are, in the limit, better than locked-down and efficient.
     * - The game should not use NFTs or Fungible tokens where they are not needed. It is about battling, not about trading.
     *
     * ECS
     * ---
     *
     * We use the Entity Component System (https://en.wikipedia.org/wiki/Entity_component_system) to structure the game:
     * - Entities are characters (and other items, but we call them Characters here).
     * - Components are their state and properties.
     * - Systems modify Components on Entities during play.

     * In a modern PC or console game, ECS has the advantage of ensuring data locality and thereby cache efficiency,
     * which is important for performance. In Cadence code we cannot and should not attempt to optimize for these
     * low level concerns as they are not exposed to us as developers and may change over time as the Flow platform evolves.
     * In particular we use dictionaries rather than arrays for Components on Entities to ensure that we can
     * access Components by type rather than by index, which is more robust and flexible but would not be cache efficient if
     * we were dealing with arrays of pointers or handles in a language that is closer to the metal like C or Rust.
     * The standardization, clear structure, and clear execution flow of ECS is still useful for efficiency and clarity of code,
     * however.
     *
     * This standardization and clarity provides the primary advantage of ECS for AutoBattler. AutoBattler is intended to be a
     * flexible game framework that allows for easy addition of new elements at each level of play. 
     * ECS is ideal for this. New Systems can be added that either ignore or interact with existing Systems and their Components,
     * and Characters can be created that use Components from different Systems without needing to change the underlying
     * Character code.
     *
     * Where we have deviated from standard ECS in our implementation is that rather than calling Systems one per tick/frame, we
     * call them repeatedly in each Turn in order to allow Systems to queue "Actions" objects that contain proposed changes to a
     * Character's Components and for each System to then review and possibly remove or update those Actions in response to other
     * System's queued Actions. This is performed in an order that is structured to reflect the flow of events in an autobrawler
     * game turn.
     * We also create multiple copies/versions of each Entity at different points in their lifecycle:
     * a Definition, an Instance, and many Turn representations. The definition is the prototype or template, the Instance
     * is a Character available in a Pass, and a Turn Character representation is used in each Turn of a Battle.
     * This separates modifications and functionality at each level.
     */


    //--------------------------------------------------------------------
    // CHARACTERS
    //--------------------------------------------------------------------

    /* entityCount
     * 
     * A unique small integer to identify entities.
     * Both Definitions and Instances use this, to ensure that they cannot
     * ever have the same IDs.
     */

    access(contract) var entityCount: UInt64


    /* InstallCharacter
     *
     * Capabilities with this entitlement can install a CharacterInstantiator
     * into a Season.
     */

    access(all) entitlement InstallCharacter


    /* InstantiateCharacter
     *
     * Capabilities with this entitlement can call a CharacterInstantiator
     * in order to create a CharacterInstance.
     */

    access(all) entitlement InstantiateCharacter


    /* CharacterDefinition
     *
     * This is the ownable resource that defines a Character.
     * The character is defined as a set of Components that amount to
     * a template.
     *
     * It installs the systems that a character uses into a season,
     * then installs a newly created CharacterInstantiator.
     *
     * We install the CharacterInstantiator into the Season
     * rather than simply vending it in order to make sure that the
     * instantiator is installed into a resource of the correct type
     * (the Season) and so cannot be removed or misused.
     *
     * The addToSeason() function can be exposed via a capability,
     * or the CharacterDefinition resource owner can co-ordinate on
     * a transaction to install the Character into a third party's
     * season without exposing the function publicly.
     *
     * Where the owner of the CharacterDefinition wishes to be able to
     * revoke access to the vended CharacterInstantiator, this is an
     * offchain legal matter rather than an onchain code matter.
     */

    access(all) resource CharacterDefinition {
        access(all) let id: UInt64
        // In FLOW tokens
        access(all) var price: UFix64
        // The vault that receives the payment for the CharacterInstantiator.
        // This is a capability to a FungibleToken.Receiver, so that the
        // CharacterDefinition owner can change the vault if needed.
        access(all) var paymentVault: Capability<&{FungibleToken.Receiver}>
        // The systems that this CharacterDefinition uses for its components.
        access(all) let systems: [Capability<&{System}>]
        // The components for this character template.
        access(all) let components: {Type: {Component}}
        // A capbility to this resource that can mint CharacterInstances.
        access(self) let instantiatorCap: Capability<auth(InstantiateCharacter) &CharacterDefinition>

        //ANTIPATTERN: passing capability to an object that has not yet been initialized
        //             into the initializer for that object on the assumption that it will be
        //             saved to the correct path with the correct auth after it is initialized.
        //
        // We need the instantiator capability for later, to install into Seasons.
        //
        // Most code assumes either one capability per account or stores resources
        // of the same type in a collection resource that manages them.
        // An account might have many CharacterDefinitions, so we cannot use a well-known path.
        // We also don't want CharacterDefinitions to look like NFTs, so we don't use a collection.
        //
        // The alternatives to passing in the character defininition are:
        // 1. Pass in a path (or a name string and construct a path from that) and save that.
        // 2. As 1, but create the capability here (can we?). This feels like it hides what should
        // 3. Have a setup() method that takes all these params and sets them later. This imposes the
        //    cost of a ? to every use of the value.
        // There are trade-offs to each of these approaches, but we use the bad approach for now
        // until we consider them and design a robust solution.
        // The main thing is that we want to avoid erroneous or malicious paths being passed in
        // at any point. Efficiency is a secondary but still important concern.
        init(
            instantiatorCap: Capability<auth(InstantiateCharacter) &CharacterDefinition>,
            vault: Capability<&{FungibleToken.Receiver}>
        ) {
            AutoBattler.entityCount = AutoBattler.entityCount + 1
            self.id = AutoBattler.entityCount
            self.price = 0.1
            self.paymentVault = vault
            self.systems = []
            self.components = {}
            self.instantiatorCap = instantiatorCap
        }

        // Add a System that is used by the Components of this CharacterDefinition.
        access(self) fun addSystem(systemCap: Capability<&{System}>) {
            var shouldAddSystem = true
            // Make sure we don't add the same system twice.
            for s in self.systems {
                if s.id == systemCap.id {
                    shouldAddSystem = false
                    break
                }
            }
            if shouldAddSystem {
                self.systems.append(systemCap)
            }
        }

        // Add a Component and a Capability for the system that manages it.
        // The Component must not already be installed in this CharacterDefinition.
        // The System Capability may already have been added, it is ignored if so.
        access(all) fun addComponent(component: {Component}, systemCap: Capability<&{System}>) {
            pre {
                ! self.components.containsKey(component.getType())
                : component.getType().identifier
                    .concat(" is already installed in this CharacterDefinition.")
            }
            self.components[component.getType()] = component
            self.addSystem(systemCap: systemCap)
        }

        // Set the FLOW token price for instantiating this CharacterDefinition.
        access(all) fun setPrice(_ price: UFix64) {
            self.price = price
        }

        // Set the Vault that receives the payment for a Season that uses this character
        // creating a Pass.
        access(all) fun setVault(_ vault: Capability<&{FungibleToken.Receiver}>) {
            self.paymentVault = vault
        }

        // Copy the Components when instantiating the character.
        access(contract) fun copyComponents(): [{Component}] {
            var components: [{Component}] = []
            for component in self.components.values {
                components.append(component.copy())
            }
            return components
        }

        // Copy the System Capabilities for the character's Components.
        // This is used to install the Systems into a Season.
        access(all) fun copySystems(): [Capability<&{System}>] {
            var systems: [Capability<&{System}>] = []
            for system in self.systems {
                systems.append(system)
            }
            return systems
        }

        // Install this CharacterDefinition into a Season.
        access(InstallCharacter) fun installCharacterDefinition(season: auth(InstallCharacter) &Season) {
            season.installCharacterDefinition(def: self.instantiatorCap)
        }

        // Pay the fee for including the character in a Season Pass.
        // This is called by the Season, so it cannot be bypassed.
        access(InstantiateCharacter) fun payForPass(payment: @{FungibleToken.Vault}) {
            pre {
                payment.balance == self.price
            }
            self.paymentVault.borrow()!.deposit(from: <-payment)
        }

        // Instantiate a CharacterInstance from this CharacterDefinition.
        // This is called via the SeasonCharacterInfo and the result placed directky into the Pass.
        // This is to ensure that CharacterInstances cannot be arbitrarily copied or modified
        // outside of the flow of the game logic.
        access(InstantiateCharacter) fun instantiate(pass: &Pass) {
            pass.addCharacter(CharacterInstance(components: self.copyComponents()))
        }
    }


    /* createCharacterDefinition
     *
     * A public function to create a CharacterDefinition resource.
     */

    access(all) fun createCharacterDefinition(
            instantiatorCap: Capability<auth(InstantiateCharacter) &CharacterDefinition>,
            vault: Capability<&{FungibleToken.Receiver}>
    ): @CharacterDefinition {
        return <- create CharacterDefinition(
            instantiatorCap: instantiatorCap,
            vault: vault)
    }


    /*
     * CharacterDefinitionInstaller
     *
     * We can't publish an auth(InstallCharacter) capability reference, and we want to deal
     * with concrete objects, rather than interfaces, for type safety/security.
     * So if you don't want to have to co-ordinate a transaction with the account of every Season
     * that wishes to use your Character, make one of these and publish a capability to it.
     */

    access(all) resource CharacterDefinitionInstaller {
        access(self) let instantiatorCap: Capability<auth(InstallCharacter) &CharacterDefinition>

        init (instantiatorCap: Capability<auth(InstallCharacter) &CharacterDefinition>) {
            self.instantiatorCap = instantiatorCap
        }

        access(all) fun characterId(): UInt64 {
            return self.instantiatorCap.borrow()!.id
        }

        access(all) fun addToSeason(season: auth(InstallCharacter) &Season) {
            self.instantiatorCap.borrow()!.installCharacterDefinition(season: season)
        }
    }


    /* createCharacterDefinitionInstaller
     *
     * A public creation function for CharacterDefinitionInstaller resources.
     */

    access(all) fun createCharacterDefinitionInstaller(instantiatorCap: Capability<auth(InstallCharacter) &CharacterDefinition>): @CharacterDefinitionInstaller {
        return <- create CharacterDefinitionInstaller(instantiatorCap: instantiatorCap)
    }


    /* SeaasonCharacterInfo
     *
     * A CharacterInstantiator installed into a Season by a CharacterDefinition
     * The price mentioned here is the in-Season currency price paid in the Store
     * during the Store phase by a player, not the Flow Token price paid to the
     * CharacterDefinition owner for instantiating the Character.
     */

    access(all) resource SeasonCharacterInfo {
        access(all) let entityID: UInt64
        access(all) let instantiator: Capability<auth(InstantiateCharacter) &CharacterDefinition>
        access(all) var availableAtLevel: UInt64
        access(all) var availableAfterBattles: UInt64
        access(all) var storePrice: UInt64

        init(
            def: Capability<auth(InstantiateCharacter) &CharacterDefinition>
        ) {
            self.entityID = def.borrow()!.id
            self.instantiator = def
            self.availableAtLevel = 1
            self.availableAfterBattles = 1
            self.storePrice = 1
        }

        access(all) fun setAvailableAtLevel(_ level: UInt64) {
            self.availableAtLevel = level
        }

        access(all) fun setAvailableAfterBattles(_ battles: UInt64) {
            self.availableAfterBattles = battles
        }

        access(all) fun setStorePrice(_ price: UInt64) {
            self.storePrice = price
        }
    }


    /* CharacterInstance
     *
     * An instance of the Character owned by a Pass.
     */

    access(all) struct CharacterInstance {
        access(all) let id: UInt64
        // The components copied from the CharacterDefinition by the CharacterInstantiator.
        access(all) let components: {Type: {Component}}

        init(components: [{Component}]) {
            AutoBattler.entityCount = AutoBattler.entityCount + 1
            self.id = AutoBattler.entityCount
            self.components = {}
            for component in components {
                self.components[component.getType()] = component
            }
        }

        access(all) fun listComponents(): [Type] {
            return self.components.keys
        }

        access(contract) fun copyComponents(): [{Component}] {
            var copiedComponents: [{Component}] = []
            for component in self.components.values {
                copiedComponents.append(component.copy())
            }
            return copiedComponents
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


   /* TurnCharacter
    *
    * The representation of a CharacterInstance within the Turns of a Battle.
    *
    * This is the live entity that is updated by the ECS during Turns.
    *
    * After the battle, Systems can modify the Instance that the TurnCharacter
    * refers to, based on the entire Battle state, if they wish.
    */

    access(all) struct TurnCharacter {
        access(all) let instanceId: UInt64
        access(all) let components: {Type: {Component}}

        //FIXME: We consume the components. We should probably copy.
        init(instanceId: UInt64, instanceComponents: [{Component}]) {
            self.instanceId = instanceId
            self.components = {}
            for component in instanceComponents {
                self.components[component.getType()] = component
            }
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

        access(contract) fun copyComponents(): [{Component}] {
            var components: [{Component}] = []
            for component in self.components.values {
                components.append(component.copy())
            }
            return components
        }

        access(contract) fun copyForNextTurn(): TurnCharacter {
            return TurnCharacter(instanceId: self.instanceId, instanceComponents: self.copyComponents())
        }
    }


    //--------------------------------------------------------------------
    // COMPONENTS
    //--------------------------------------------------------------------

    /* Component
     *
     * The data for an ECS Component, added to a CharacterInstance
     * (and specified in a CharacterDefinition).
     *
     * Used instead of AnyStruct so that we can check types usefully,
     * and add features if needed.
     */

    access(all) struct interface Component {
        access(all) fun copy(): {Component}
    }


    /* Attribute
     *
     * A Component that tracks a changeable resource or capability
     * of a Character that can be altered by Actions during a Turn.
     * e.g. health, aura, speed, magic, luck
     */

    access(all) struct interface Attribute: Component {
        access(all) var value: Int8

        access(all) fun set(to: Int8)
    }


    /* Ability
     *
     * A component that tracks an ability or power of a Character
     * that can be used during a Turn against an Atttribute
     * (often of another Character, but sometimes of itself).
     * e.g.: damage, heal, slow, speed-up, burn, drain, boost
     */

    access(all) struct interface Ability : Component {
        access(all) let affectsAttribute: Type
        access(all) var amount:           Int8
    }


    /* Metadata
     *
     * On-chain metadata Component until we plumb in ipfs.
    */

    access(all) struct Metadata: Component {
        access(all) var name: String
        access(all) var description: String
        access(all) var imageUrl: String

        init(name: String, description: String, imageUrl: String) {
            self.name = name
            self.description = description
            self.imageUrl = imageUrl
        }

        access(all) fun copy(): {Component} {
            return Metadata (
                name: self.name,
                description: self.description,
                imageUrl: self.imageUrl
            )
        }
    }


    /* Action
     *
     * An Action is a proposed change to the state of a CharacterInstance.
     * It is created by a System during a Turn and is applied
     * by a System after the filter stage of the Turn.
     */

    access(all) struct interface Action {
        access(all) fun perform()
        // This is for development only.
        access(all) fun toString(): String
    }


    //--------------------------------------------------------------------
    // SYSTEMS
    //--------------------------------------------------------------------

    /* System
     *
     * A System that updates Components on Entities in phases of a Turn
     * in a Round via Actions.
     *
     * Systems are pure library code. They are not intended to be part of
     * the economics of the game.
     * 
     * As with CharacterDefinitions, they may be exposed or not by their
     * possessor. 
     *
     * They are installed into a Season by a CharacterDefinition.
     *
     * Most functions operate on TurnCharacter objects within a Turn, but
     * afterBattle can affect CharacterInstance objects to persist changes
     * between Battles.
     * FIXME: Can we make that more secure? See next note.
     *
     * WARNING: You must trust any Systems that you use. They have the ability
     * to mutate CharacterInstances, and may react to Actions from other Systems
     * in ways that the authors of the other System may not expect.
     * The design of AutoBattler protects you from this as much as possible,
     * but ultimately flexibility and extensibility win out over restrictions
     * here.
     */

    access(all) resource interface System {
        // Probably some metadata and the renderer.
        access(contract) var url: String

        // This is called *once* to modify onchain state after a battle
        // has been battle()d.
        access(all) fun afterBattle(battle: &Battle)

        // These are called once per turn in the order given here.
        // add*() methods are called before filter*() methods.
        // add*() methods are used to add Actions to the Turn,
        // filter*() methods are used to remove or replace Actions in the Turn.
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

    /* Health
     *
     * Hit points, constitution, call it what you like but if your
     * Character runs out of it then it will faint and be out of the
     * Battle.
     */

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


    /* Damage
     *
     * A Component that represents how much the Character's attacks will
     * reduce their opponent's Health.
     *
     * This might be via a weapon, a spell, or a natural ability.
     */

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


    /* Attack
     *
     * An action that applies the attacker's Damage to the defender's Health
     * during the combat phase.
     */

    access(all) struct Attack: Action {
        access(all) let attacker: &TurnCharacter
        access(all) let defender: &TurnCharacter

        init(attacker: &TurnCharacter, defender: &TurnCharacter) {
            self.attacker = attacker
            self.defender = defender
        }

        //FIXME: Defender should get to have a say. e.g. if defender has defendAttack() method, it should be called.
        //       Subject defines verb, verb & subject go to object and ask it if it can handle them or should we do the default.
        access(all) fun perform() {
            let defenderHealth: &Health = self.defender.accessComponent(Type<Health>()) as! &Health
            let attackerDamage: &Damage = self.attacker.accessComponent(Type<Damage>()) as! &Damage
            let preHealth = defenderHealth.value
            defenderHealth.set(to: preHealth - attackerDamage.amount)
        }

        access(all) fun toString(): String {
            return "Attack. Attacker: ".concat(self.attacker.instanceId.toString())
                .concat(", Defender: ".concat(self.defender.instanceId.toString()))
                .concat(", Damage: ".concat((self.attacker.accessComponent(Type<Damage>()) as! &Damage).amount.toString()))
                .concat(", Health: ".concat((self.defender.accessComponent(Type<Health>()) as! &Health).value.toString()))
        }
    }


    /* Faint
     *
     * An action that is queued by the DamageSystem when a Character's Health is zero or less.
     * It requests the removal of the Character from the Turn by adding it to the removes list.
     */

    access(all) struct Faint: Action {
        access(all) let entity: &TurnCharacter
        access(all) let turn: &Turn

        init(entity: &TurnCharacter, turn: &Turn) {
            self.entity = entity
            self.turn = turn
        }

        access(all) fun perform() {
            let entityID = self.entity.instanceId
            self.turn.addRemove(id: entityID)
        }

        access(all) fun toString(): String {
            return "Faint. Entity: ".concat(self.entity.instanceId.toString())
        }
    }


    /* DamageSystem
     *
     * The System that manages Health and Damage Components on Characters.
     * It will add Attacks and Faints to the Turn based on the Character's
     * Components.
     */

    access(all) resource DamageSystem: System {
        access(contract) var url: String

        init(url: String) {
            self.url = url
        }

        access(all) fun initializeEntity(_ entity: &CharacterInstance) {}
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


    /* MetadataSystem
     *
     * A no-op system for the onchain metadata.
     * This is inefficient but temporary, and more robust than creating a special case
     * path for metadata when adding it to an entity.
     *
     * FIXME: how *shuld* we handle this?
     */

    access(all) resource MetadataSystem: System {
        access(contract) var url: String

        init(url: String) { self.url = url }

        access(all) fun initializeEntity(_ entity: &CharacterInstance) {}
        access(all) fun afterBattle(battle: &Battle) {}

        access(all) fun addBuffs(_ turn: &Turn) {}
        access(all) fun filterBuffs(_ turn: &Turn) {}

        access(all) fun addAttacks(_ turn: &Turn) {}
        access(all) fun filterAttacks(_ turn: &Turn) {}

        access(all) fun addRecovers(_ turn: &Turn) {}
        access(all) fun filterRecovers(_ turn: &Turn) {}

        access(all) fun addResolves(_ turn: &Turn) {}
        access(all) fun filterResolves(_ turn: &Turn) {}
    }


    //--------------------------------------------------------------------
    // TURNS
    //--------------------------------------------------------------------

    /*
     * Turn
     *
     * A single time slice in a Battle, in which Actions are queued
     * and applied by Systems to Characters.
     */

    access(all) struct Turn {
        // The team states from the end of the previous Turn,
        // before the Actions of the current Turn are applied.
        // If this is the first Turn, the team states are set from the
        // the initial team states.
        access(contract) var myTeam:     [TurnCharacter]
        access(contract) var theirTeam:  [TurnCharacter]
        // A list of IDs of CharacterInstances that are to be removed
        // when the state of the Turn is copied to the next Turn.
        access(contract) var removes:    [UInt64]

        // Actions for successive phases of this Turn.
        // They are added, filtered, and applied by each system in turn.
        access(self) var     buffs:      [{Action}]
        access(self) var     attacks:    [{Action}]
        access(self) var     recoveries: [{Action}]
        access(self) var     resolves:   [{Action}]

        init(myTeam: [TurnCharacter], theirTeam: [TurnCharacter]) {
            self.myTeam = myTeam
            self.theirTeam = theirTeam
            self.buffs = []
            self.attacks = []
            self.recoveries = []
            self.resolves = []
            self.removes = []
        }

        // This is for development only.
        access(all) fun toString(): String {
            var str = "Mine: ["
            .concat(
                String.join(
                    self.myTeam.map<String>(fun (e: TurnCharacter): String { return e.instanceId.toString() }),
                    separator: ", "
                )
            )
            .concat("], Theirs: [")
            .concat(
                String.join(
                    self.theirTeam.map<String>(fun (e: TurnCharacter): String { return e.instanceId.toString() }),
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

        // Copy the Turn to a new Turn, removing any Characters that are in the removes list.
        // This should be called "next" or another better name.
        access(contract) fun copy(): Turn {
            var myNewTeam: [TurnCharacter] = []
            for my in self.myTeam {
                if ! self.removes.contains(my.instanceId) {
                        myNewTeam.append(my.copyForNextTurn())
                }
            }
            var theirNewTeam: [TurnCharacter] = []
            for their in self.theirTeam {
                if ! self.removes.contains(their.instanceId) {
                    theirNewTeam.append(their.copyForNextTurn())
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
    // BATTLES
    //--------------------------------------------------------------------

    /* BattleResult
     *
     * The status of a Battle.
     */

    access(all) enum BattleResult: UInt8 {
        // The Battle has not yet been resolved.
        access(all) case Undecided
        // The player's team won the battle.
        access(all) case Win
        // The player's team lost the battle.
        access(all) case Lose
        // Neither team won the battle.
        access(all) case Draw
    }


    /* BattleResolved
     *
     * This event is emitted when a Battle is resolved in order to
     * publish the result of the battle to the blockchain.
     *
     * The fine-grained details of the Battle are not stored onchain,
     * but can be reconstructed by calling the correct methods on the
     * Battle object. This saves on onchain storage costs and allows
     * for the Battle to be replayed offchain in a web interface or
     * other client.
     *
     * The result is a UInt8 that corresponds to the BattleResult enum.
     */

    access(all) event BattleResolved(result: UInt8)


    /* Battle
     *
     * A struct that commits the player's team to a battle with another team,
     * chosen at some point in the past by another player and matched
     * with them by the SeasonDelegate.
     */

    access(all) struct Battle {
        access(all) var result:                 BattleResult
        access(self) let randomnessBlock:       UInt64
        access(self) var randomnessFulfilled:   Bool
        access(contract) let myInitialTeam:    [CharacterInstance]
        access(contract) var theirInitialTeam: [CharacterInstance]

        init(myTeam: [CharacterInstance]) {
            self.result = BattleResult.Undecided
            // Commit ourselves to a specific, currently unknown, future slice of entropy for decision making.
            self.randomnessBlock = getCurrentBlock().height
            self.randomnessFulfilled = false
            self.myInitialTeam = myTeam
            self.theirInitialTeam = []
        }

        access(self) fun instancesToTurnCharacters (instances: [CharacterInstance]): [TurnCharacter] {
            let turnChars: [TurnCharacter] = []
            for instance in instances {
                turnChars.append(TurnCharacter(instanceId: instance.id, instanceComponents: instance.copyComponents()))
            }
            return turnChars
        }

        access(contract) fun battle(_ theirTeam: [CharacterInstance], systems: &[Capability<&{System}>]): BattleResult {
            self.theirInitialTeam = theirTeam
            let turns = self.simulate(systems: systems)
            self.result = self.determineResult(turns: turns)
            for system in systems {
                 system.borrow()!.afterBattle(battle: &self as &Battle)
            }
            emit BattleResolved(result: self.result.rawValue)
            return self.result
        }

        // Simulates the battle, returning a list of Turns.
        // This is called once onchain to resolve the battle,
        // and as many times as needed offchain to recreate the
        // events of the battle for display or analysis.
        access(contract) fun simulate(systems: &[Capability<&{System}>]): [Turn] {
            var prng = self.prng()
            var turns = [Turn(
                myTeam:    self.instancesToTurnCharacters(instances: self.myInitialTeam),
                theirTeam: self.instancesToTurnCharacters(instances: self.theirInitialTeam)
            )]
            while true {
                var turn = turns[turns.length - 1].copy()

                if turn.myTeam.length == 0 || turn.theirTeam.length == 0 {
                    turns.append(turn)
                    break
                }

                for system in systems {
                    system.borrow()!.addBuffs(&turn as &Turn)
                }
                for system in systems {
                    system.borrow()!.filterBuffs(&turn as &Turn)
                }
                turn.applyBuffs()

                for system in systems {
                    system.borrow()!.addAttacks(&turn as &Turn)
                }
                for system in systems {
                    system.borrow()!.filterAttacks(&turn as &Turn)
                }
                turn.applyAttacks()

                for system in systems {
                    system.borrow()!.addRecovers(&turn as &Turn)
                }
                for system in systems {
                    system.borrow()!.filterRecovers(&turn as &Turn)
                }
                turn.applyRecovers()

                for system in systems {
                    system.borrow()!.addResolves(&turn as &Turn)
                }
                for system in systems {
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
            //FIXME: Use a real PRNG!
            //FIXME: Use real salt!!!
            let entropy: [UInt8] = self._fulfillRandomness()
            let salt: UInt64 = 112123123412345
            return ToyPRNG.Xorshift64(
                seed: UInt64.fromBigEndianBytes(entropy.slice(from: 0, upTo: 8))!,
                salt: salt
            )
        }

        // Fetch the randomness for the block number that we committed to
        access(contract) fun _fulfillRandomness(): [UInt8] {
            self.randomnessFulfilled = true
            return RandomBeaconHistory.sourceOfRandomness(atBlockHeight: self.randomnessBlock).value
        }
    }


    //--------------------------------------------------------------------
    // PASSES
    //--------------------------------------------------------------------

    /* RunStage
    *
    * A Pass alternates between two stages, Shop and Battle.
    */

    access(all) enum RunStage: UInt8 {
        // The player can purchase new items and update their team
        access(all) case Store
        // Tthe player is engaged in a battle and has a current Battle object.
        access(all) case Battle
    }


    /* Pass
     *
     * This resource represents a player's paid access to a Season,
     * and stores the state and history of their playthrough of that season.
     */

    access(all) resource Pass {
        access(all) let  season: Capability<auth(SeasonPass) &Season>
        // Store character instances owned by this pass
        access(all) let  characters: {UInt64: CharacterInstance}
        access(all) let  myTeam: [UInt64]
        access(self) var battles: [Battle]
        access(all) var  coins: UInt64
        access(all) var  stage: RunStage
        access(all) var  nextCharacterId: UInt64 //????????????

        init(season: Capability<auth(SeasonPass) &Season>) {
            self.season = season
            self.characters = {}
            self.myTeam = []
            self.battles = []
            self.coins = 0
            self.stage = RunStage.Store
            self.nextCharacterId = 0
        }

        access(contract) fun setStage(_ stage: RunStage) {
            self.stage = stage
        }

        access(contract) fun setCoins(_ coins: UInt64) {
            self.coins = coins
        }

        access(contract) fun addCharacter(_ character: CharacterInstance) {
            let id = self.nextCharacterId
            self.nextCharacterId = self.nextCharacterId + 1
            self.characters[id] = character
        }

        access(all) fun buyCharacter(id: UInt64) {
            self.season.borrow()!.buyCharacter(pass: &self as &Pass, id: id)
        }

        access(all) fun addCharacterToTeam(id: UInt64, index: Int) {
            pre {
                self.stage == RunStage.Store
                self.characters[id] != nil
            }
            if index == self.myTeam.length {
                self.myTeam.append(id)
            } else {
                // This shifts existing elements rather than overwriting.
                self.myTeam.insert(at: index, id)
            }
        }

        access(all) fun removeCharacterFromTeam(index: Int) {
            pre { self.stage == RunStage.Store }
            let _ = self.myTeam.remove(at: index)
        }

        access(all) fun startBattle() {
            pre {
                self.stage == RunStage.Store
            }
            let this: &Pass = &self
            let team = self.myTeam.map(fun(element: UInt64): CharacterInstance {
                return CharacterInstance(components: this.characters[element]?.copyComponents()!)
            })
            self.battles.append(Battle(myTeam: team))
            self.setStage(RunStage.Battle)
        }

        access(all) fun endBattle(): BattleResult {
            pre {
                self.stage == RunStage.Battle
            }
            let season = self.season.borrow()!
            // FIXME: Use the Delegate to CHOOSE AN OPPOSING TEAM!!!
            let theirTeam: [CharacterInstance] = [
                CharacterInstance(components: self.characters[self.myTeam[1]]!.copyComponents()),
                CharacterInstance(components: self.characters[self.myTeam[0]]!.copyComponents())
                ]
            let result = self.battles[self.battles.length - 1].battle(theirTeam, systems: season.systems)
            // These should go in the Pass.
            self.setStage(RunStage.Store)
            self.setCoins(season.currencyPerStorePhase)
            return result
        }

        access(all) fun simulateBattle (index: UInt64): [Turn] {
            let systems = self.season.borrow()!.systems
            return self.battles[index].simulate(systems: systems)
        }

        access(contract) fun newBattle(systems: [Capability<&{System}>]) {
            // Create a battle with the characters in myTeam
            // This will need to be updated based on how Battle works with CharacterInstance
            let team: [CharacterInstance] = []
            for id in self.myTeam {
                if let character = &self.characters[id] as &CharacterInstance? {
                    // Create a copy of the character for battle
                    team.append(CharacterInstance(components: character.copyComponents()))
                }
            }
            let battle = Battle(myTeam: team)
            self.battles.append(battle)
        }
    }


    //--------------------------------------------------------------------
    // SEASONS
    //--------------------------------------------------------------------

    /*
     * PurchaseSeasonPass
     *
     * The access on a Season capability required to purchase a Pass.
     */

    access(all) entitlement PurchaseSeasonPass


    /* SeasonPass
     *
     * The access granted to a Pass resource purchased from the Season.
     */

    access(all) entitlement SeasonPass


    /* Season
     *
     * A Season is a collection of Characters, Systems, and other resources
     * with a given currency and the ability to purchase a Season Pass
     * in order to play through the Season.
     *
     * The currency mentioned here is the in-Season currency, not a Fungible Token.
     *
     * To ensure object ownership, the Season is a resource that delegates configuration
     * details to a SeasonDelegate. This is so that the CharacterDefinitions and
     * Systems that the Season interacts with can be sure that they are dealing with
     * known behaviour from the concrete type of the Season they are interacting with.
     */

    access(all) resource Season {
        access(all) var url: String
        access(all) var name: String
        access(all) let currencyName: String
        access(all) let currencySymbol: String
        access(all) var currencyPerStorePhase: UInt64
        access(all) var runPrice: UFix64
        access(all) var paymentVault: Capability<&{FungibleToken.Receiver}>
        // This is an array so that it has a guaranteed order.
        access(all) var systems: [Capability<&{System}>]
        access(all) var characters: @{UInt64: SeasonCharacterInfo}
        access(all) let delegate: @{SeasonDelegate}
        //FIXME: Cached here for now
        access(self) let seasonPassCap: Capability<auth(SeasonPass) &Season>

        init(
            url: String,
            name: String,
            delegate: @{SeasonDelegate},
            currencyName: String,
            currencySymbol: String,
            currencyPerStorePhase: UInt64,
            runPrice: UFix64,
            paymentVault: Capability<&{FungibleToken.Receiver}>,
            seasonPassCap: Capability<auth(SeasonPass) &Season>
        ) {
            self.url = url
            self.name = name
            self.currencyName = currencyName
            self.currencySymbol = currencySymbol
            self.characters <- {}
            self.currencyPerStorePhase = currencyPerStorePhase
            self.runPrice = runPrice
            self.delegate <- delegate
            self.paymentVault = paymentVault
            self.systems = []
            self.seasonPassCap = seasonPassCap
        }

        access(self) fun addSystem(systemCap: Capability<&{System}>) {
            var shouldAddSystem = true
            // Make sure we don't add the same system twice.
            for s in self.systems {
                if s.id == systemCap.id {
                    shouldAddSystem = false
                    break
                }
            }
            if shouldAddSystem {
                self.systems.append(systemCap)
            }
        }

        // Require Install entitlement so that only the owner of the Season can install CharacterDefinitions.
        access(InstallCharacter) fun installCharacterDefinition(
            def: Capability<auth(InstantiateCharacter) &CharacterDefinition>
        ) {
            pre {
                def.borrow() != nil: "CharacterDefinition does not exist."
                self.characters.length < 1000: "Too many characters in season."
            }
            var characterInfo <- create SeasonCharacterInfo(
                    def: def
            )
            let entityId = characterInfo.entityID
            self.characters[entityId] <-! characterInfo
            for system in def.borrow()!.copySystems() {
                self.addSystem(systemCap: system)
            }
        }

        access(all) fun setCharacterDetails(
            entityID: UInt64,
            availableAtLevel: UInt64,
            availableAfterBattles: UInt64,
            storePrice: UInt64
        ) {
            if let character: &SeasonCharacterInfo = &self.characters[entityID] {
                character.setAvailableAtLevel(availableAtLevel)
                character.setAvailableAfterBattles(availableAfterBattles)
                character.setStorePrice(storePrice)
            }
        }

        access(all) fun getAvailableCharacters(level: UInt64, battles: UInt64): [&SeasonCharacterInfo] {
            let this: &Season = &self
            var available: [&SeasonCharacterInfo] = []
            self.characters.forEachKey(
                fun (key: UInt64) : Bool {
                    if let character: &SeasonCharacterInfo = this.characters[key] {
                        available.append(character)
                    }
                    return true
                }
            )
            return available
        }

        access(all) fun getCharacterIds(): [UInt64] {
            return self.characters.keys
        }

        access(all) fun getCharacterPrice(entityID: UInt64): UInt64? {
            if let character: &SeasonCharacterInfo = &self.characters[entityID] {
                    return character.storePrice
                } else {
                return nil
            }
        }

        access(self) fun payPassCharactersFees(payments: @FlowToken.Vault): @FlowToken.Vault {
            let this: &Season = &self
            let pay: auth(FungibleToken.Withdraw) &FlowToken.Vault = &payments
            self.characters.forEachKey(
                fun (key: UInt64) : Bool {
                    if let character: &SeasonCharacterInfo = this.characters[key] {
                        let fee = character.instantiator.borrow()!.price
                        let feeVault <- pay.withdraw(amount: fee)
                        character.instantiator.borrow()!.payForPass(payment: <-feeVault)
                    }
                    return true
                }
            )
            return <-payments
        }

        access(PurchaseSeasonPass) fun purchasePass(payment: @FlowToken.Vault): @Pass {
            pre {
                payment.balance == self.runPrice: "Incorrect payment for Season Pass."
            }
            let remainder <- self.payPassCharactersFees(payments: <-payment)
            self.paymentVault.borrow()!.deposit(from: <-remainder)
            return <-create Pass(season: self.seasonPassCap)
        }

        access(contract) fun buyCharacter(pass: &Pass, id: UInt64) {
            if let character: &SeasonCharacterInfo = &self.characters[id] {
                character.instantiator.borrow()!.instantiate(pass:pass)
            }
        }
    }


    /* createSeason
     *
     * Create a Season resource with the given configuration.
     */

    access(all) fun createSeason(
        url: String, name: String, delegate: @{SeasonDelegate},
        currencyName: String, currencySymbol: String, currencyPerStorePhase: UInt64,
        runPrice: UFix64, paymentVaultCap: Capability<&{FungibleToken.Receiver}>,
        seasonPassCap: Capability<auth(SeasonPass) &AutoBattler.Season>): @Season {
        return <-create Season(
            url: url,
            name: name,
            delegate: <-delegate,
            currencyName: currencyName,
            currencySymbol: currencySymbol,
            currencyPerStorePhase: currencyPerStorePhase,
            runPrice: runPrice,
            paymentVault: paymentVaultCap,
            seasonPassCap: seasonPassCap
        )
    }


    /* SeasonDelegate
     *
     * We contain custom logic for Season behaviour within resources that implement
     * this interface.
     * This is so that we can always pass Seasons *as* Seasons, for type safety,
     * and so that malicious code never has internal access to Seasons.
     */

    access(all) resource interface SeasonDelegate {
        // TODO:
        // Custom purchase logic.
        // Custom matching logic.
        // Custom game loop logic.

        // Note that the delegate cannot access the Entities directly,
        // as must not be able to copy them.

        access(contract) fun selectOpposingTeam(battle: &Battle): [CharacterInstance]
    }


    /* DefaultSeasonDelegate
     *
     * This is the SeasonDelegate that implements the basic logic for a Season.
     */

    access(all) resource DefaultSeasonDelegate: SeasonDelegate {
        access(contract) fun selectOpposingTeam(battle: &Battle): [CharacterInstance] {
            return []
        }
    }


    /* createSeasonDelegate
     *
     * This creates a SeasonDelegate implementing the basic logic for a season.
     */

    access(all) fun createDefaultSeasonDelegate (): @{SeasonDelegate} {
        return <- create DefaultSeasonDelegate()
    }


    /* SeasonPassVendor
     *
     * A resource that a Season owner can publish a capability to
     * in order to sell Season Passes without having to coordinate
     * a transaction with the buyer.
    */

    access(all) resource SeasonPassVendor {
      access(self) let purchaseCap: Capability<auth(PurchaseSeasonPass) &Season>

        init (seasonPassCap: Capability<auth(PurchaseSeasonPass) &Season>) {
            self.purchaseCap = seasonPassCap
        }

        access(all) fun seasonName(): String {
            return self.purchaseCap.borrow()!.name
        }

        access(all) fun seasonPassCost(): UFix64 {
            return self.purchaseCap.borrow()!.runPrice
        }

        access(all) fun purchaseSeasonPass(payment: @FlowToken.Vault): @Pass {
            return <- self.purchaseCap.borrow()!.purchasePass(payment: <-payment)
        }
    }


    /* createSeasonPassVendor
     *
     * A public creation function for SeasonPassVendor resources.
     */

    access(all) fun createSeasonPassVendor(seasonPassCap: Capability<auth(PurchaseSeasonPass) &Season>): @SeasonPassVendor {
        return <- create SeasonPassVendor(seasonPassCap: seasonPassCap)
    }


    //--------------------------------------------------------------------
    // CONTRACT INITIALIZER
    //--------------------------------------------------------------------

    init () {
        self.entityCount = 0

        // Create and publish the base attribute and damage System.
        // We *don't* provide a public field containing the path to it,
        // as that pattern is deprecated.
        let battleSystem <- create DamageSystem(url: "ipfs://blah/")
        self.account.storage.save(<- battleSystem, to: /storage/battleSystem)
        let battleSystemCapability = self.account.capabilities.storage.issue<&{System}>(/storage/battleSystem)
        self.account.capabilities.publish(battleSystemCapability, at: /public/battleSystem)

        // This should not make it to production. Metadata should be on ipfs.
        let metadataSystem <- create DamageSystem(url: "ipfs://blahblah/")
        self.account.storage.save(<- metadataSystem, to: /storage/metadataSystem)
        let metadataSystemCapability = self.account.capabilities.storage.issue<&{System}>(/storage/metadataSystem)
        self.account.capabilities.publish(metadataSystemCapability, at: /public/metadataSystem)
    }
}
