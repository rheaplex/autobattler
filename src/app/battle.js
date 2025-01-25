import React from "react";
import {useParams} from "react-router-dom";
import {useEffect, useState} from "react";

import * as fcl from "@onflow/fcl";
import { BATTLE_CREATED_EVENT, BATTLE_ADVANCED_EVENT, BATTLE_ENDED_EVENT, CARD_FAINTED_EVENT } from "./fcl";

function BattleEvents() {
  const {eventKey} = useParams()
  const [events, setEvents] = useState([])
  useEffect(
    () =>
      fcl.events(eventKey).subscribe((event) => {
        setEvents((oldEvents) => [event, ...oldEvents])
      }),
    [eventKey]
  )
  

  function battleCreated(battle, index) {
    return (
      <div
      key={`${battle.battleID}-${index}`}
      style={{
        border: "1px solid #ccc",
        borderRadius: "8px",
        padding: "1rem",
        margin: "1rem 0",
        backgroundColor: "#ccf",
      }}
    >
        <h2>Battle Created: {battle.battleID.toString()}</h2>
        <p>Team1 Address: {battle.team1Address}</p>
        <p>Team2 Address: {battle.team2Address}</p>
        <p>Team1 IDs<br/>{battle.team1IDs.join(", ")}</p>
        <p>Team2 IDs<br/>{battle.team2IDs.join(", ")}</p>
      </div>
    )
  }

  function battleEnded(battle, index) {
      return (
        <div
          key={`${battle.battleID}-${index}`}
          style={{
            border: "1px solid #ccc",
            borderRadius: "8px",
            padding: "1rem",
            margin: "1rem 0",
            backgroundColor: "#aaf",
          }}
        >
          <h2>Battle: {battle.battleID.toString()} Ended{!battle.winner && !battle.loser && " in a draw"}</h2>
          {battle.winner && <p>Winner: {battle.winner}</p>}
          {battle.loser && <p>Loser: {battle.loser}</p>}
          {!battle.winner && !battle.loser && <p>No winner/loser</p>}
        </div>
      )
  }

  function battleAdvanced(battle, index) {
      return (
        <div
          key={`${battle.battleID}-${index}`}
          style={{
            border: "1px solid #ccc",
            borderRadius: "8px",
            padding: "1rem",
            margin: "1rem 0",
            backgroundColor: "#f9f9f9",
          }}
        >
          <h2>Battle: {battle.battleID.toString()} Turn: {battle.turnIndex.toString()}</h2>
          <p>Attacker Card Index: {battle.attackerCardIndex.toString()}</p>
          <p>Attacker Card ID: {battle.attackerCardID.toString()}</p>
          <p>Damage to Attacker: {battle.damageToAttacker.toString()}</p>
          <p>New Attacker Health: {battle.newAttackerHealth.toString()}</p>
          <p>Defender Card Index: {battle.defenderCardIndex.toString()}</p>
          <p>Defender Card ID: {battle.defenderCardID.toString()}</p>
          <p>Damage to Defender: {battle.damageToDefender.toString()}</p>
          <p>New Defender Health: {battle.newDefenderHealth.toString()}</p>
        </div>
      )
  }

  function cardFainted(battle, index) {
      return (
        <div
          key={`${battle.battleID}-${index}`}
          style={{
            border: "1px solid #ccc",
            borderRadius: "8px",
            padding: "1rem",
            margin: "1rem 0",
            backgroundColor: "#fcc",
          }}
        >
          <h2>Card Fainted</h2>
          <h3>Battle ID: {battle.battleID.toString()}</h3>
          <p>Card ID: {battle.cardID.toString()}</p>
        </div>
      )
  }

  // Render each battle event as a "box"
  return (
    <div style={{ padding: "1rem" }}>
      <h1>Battle Events</h1>
      {events.map((event, index) => {
          switch (event.type) {
            case BATTLE_CREATED_EVENT:
              return battleCreated(event.data, index);
            case BATTLE_ADVANCED_EVENT:
              return battleAdvanced(event.data, index);
            case BATTLE_ENDED_EVENT:
              return battleEnded(event.data, index);
            case CARD_FAINTED_EVENT:
              return cardFainted(event.data, index);
            default:
              return null;//<div>{JSON.stringify(event)}</div>;
          }
        })}
      {events.length === 0 && <p>No battles have been created yet.</p>}
    </div>
  );
}

export default BattleEvents;
