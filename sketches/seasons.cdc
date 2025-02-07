access(all) resource interface Card {
  access(all) beforeBattle(Gamestate)
  access(all) nextTurn(Gamestate)
  access(all) afterBattle(Gamestate)
  access(all) states() [State]
  access(all) applyEffect(Gamestate, State)
}

interface CardUse {
          payToGetInterfaceToCardForDomain()
}

access(all) resource interface Domain {

}

access(all) resource Run {}

access(all) resource interface BattleAccessForCard {
     history() [Gamestate]
     turn() // zero is before battle?
     // The card can explicitly modify these.
     ourList()
     theirList()
     
}

BattleEvent

access(all) resource Battle {
 history:[GameState]
currentState()
playerAGold
playerAHearts
playerARibbons
playerATeam

payToStartRun
commitToBattle
catlculateBattle <internal>
battleResult <public, calls finalize, see notes>

} ?

access(all) resource interface State {
   access(all) function inEffect(Card, Gamestate)
   access(all) function applyEffectTo(Card, Gamestate)

}