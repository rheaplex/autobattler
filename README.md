AutoGame
========

Front end code: JS via bun.

Smart Contracts: Cadence via flow.

To Run Locally
--------------

Console one:
```
flow emulator
```

Console two:
```
flow project deploy
flow dev-wallet
```

Console three:
```
bash scripts/test-setup.sh &&\
bash scripts/test-domain-create.sh &&\
bash scripts/test-run-start.sh &&\
bash scripts/test-battle-start.sh &&\
bash scripts/test-report.sh &&\
bash scripts/test-battle-finish.sh &&\
bash scripts/test-report.sh &&\
bash scripts/test-battle-result.sh
```

Structure
-----------

We use the Entity Component System (https://en.wikipedia.org/wiki/Entity_component_system) to structure the game:
- Entities are characters or pieces.
- Components are their state.
- Systems modify Components on Entities.

The ECS is used within Seasons:
- Each Season consists of Entities and Systems.
- A player experiences a Season in a PlayThrough.
- Each PlayThrough consists of a series of Battles.
- Each Battle consists of a series of Turns. Turns resolve Actions simultaneously, making them "Game Turns" rather than "Player Turns" (https://en.wikipedia.org/wiki/Game_mechanics#Turns).
- Actions modify Components on Entities and may add or remove Components to or remove them from Battles.
- Each Turn consists of a series of Phases:
    * Buffs - Initial power-ups.
    * Attacks - Exchanges of Actions against other Entities.
    * Recoveries - Actions that heal or otherwise improve Entities' Component states.
    * Resolves - Actions that add, remove, or move Battle Components.
- Phases do not exist as resources or structs, rather the Turn repeatedly calls the Season's Systems to successively add and filter Actions for each turn.
