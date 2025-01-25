import * as fcl from "@onflow/fcl";
import flowJSON from "../../flow.json";

function configFCL() {
    fcl.config({
        'flow.network': 'emulator',
        'accessNode.api': 'http://localhost:8888'
    }).load({ flowJSON});
}

const BATTLE_CREATED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.BattleCreated`;
const BATTLE_ADVANCED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.BattleTurnAdvanced`;
const BATTLE_ENDED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.BattleEnded`;

const CARD_FAINTED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.CardFainted`;
const CARD_CREATED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.CardCreated`;

export { 
    configFCL, 
    BATTLE_CREATED_EVENT, BATTLE_ADVANCED_EVENT, BATTLE_ENDED_EVENT,
    CARD_FAINTED_EVENT, CARD_CREATED_EVENT
 };