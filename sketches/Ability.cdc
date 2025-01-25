// Trigger time?
//
// on...
// start of battle
// hurt
// freezing
// fainting
// teammate freezing
// teammate fainting

/*

access(all) attachment Ability for CharacterInstance {
    // How many turns it takes to initially activate the ability
    access(all) var setup: UInt8
    // How many turns the ability is then active for
    access(all) var active: UInt8
    // How long after using the ability before it can be used again
    access(all) var cooldown: UInt8
    // How many times this ability can be used each game
    access(all) var usesPerGame: UInt8
    // How likely the ability is to fail
    access(all) var reliabilityPercentage: UInt8
    // How many times the ability can fail before being disabled for this game
    access(all) var failuresBeforeBreaking: UInt8
    // The damage done to an opposing character when used in a turn
    access(all) var damagePerTurn: UInt8
    // The health added to the attaced character when used in a turn
    access(all) var healthPerTurn: UInt8

    view access(all) fun designPoints(): Int {
        return 1
    }
}

access(all) Struct AbilityState {
    // Ability
    // Turn count, for setup/cooldown
}

*/