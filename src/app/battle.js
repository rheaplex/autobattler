import React from "react";
import * as fcl from "@onflow/fcl";
import flowJSON from "../../flow.json";

fcl.config({
    'flow.network': 'emulator',
    'accessNode.api': 'http://localhost:3569'
  })
  .load({ flowJSON})

// Adjust the event identifier if your contract address or name is different
const BATTLE_CREATED_EVENT = `A.${flowJSON.contracts.AutoGame.aliases.emulator}.AutoGame.BattleCreated`;

function BattleEvents() {
  const [battles, setBattles] = React.useState([]);

  React.useEffect(() => {
    // Subscribe to the BattleCreated event
    const unsubscribe = fcl
      .events(BATTLE_CREATED_EVENT)
      .subscribe((battleEvent) => {
        // The event fields typically match what you defined in Cadence, e.g.:
        // event BattleCreated(
        //   battleID: UInt64,
        //   team1Address: Address,
        //   team2Address: Address,
        //   team1IDs: [UInt64],
        //   team2IDs: [UInt64]
        // )
        //
        // The "battleEvent" param is an object with these fields.

        // Add the new event to our local state
        setBattles((prevBattles) => [battleEvent, ...prevBattles]);
      });

    // Cleanup when the component unmounts
    return () => {
      unsubscribe();
    };
  }, []);

  // Render each battle event as a "box"
  return (
    <div style={{ padding: "1rem" }}>
      <h2>New Battles</h2>
      {battles.map((battle, index) => (
        <div
          key={`${battle.battleID}-${index}`}
          style={{
            border: "1px solid #ccc",
            borderRadius: "8px",
            padding: "1rem",
            margin: "1rem 0",
          }}
        >
          <h3>Battle ID: {battle.battleID.toString()}</h3>
          <p>Team1 Address: {battle.team1Address}</p>
          <p>Team2 Address: {battle.team2Address}</p>

          <p>Team1 IDs: {JSON.stringify(battle.team1IDs)}</p>
          <p>Team2 IDs: {JSON.stringify(battle.team2IDs)}</p>
        </div>
      ))}
      {battles.length === 0 && <p>No battles have been created yet.</p>}
    </div>
  );
}

export default BattleEvents;
