import React from "react";
import {useParams} from "react-router-dom";
import {useEffect, useState} from "react";

import * as fcl from "@onflow/fcl";
import { CARD_CREATED_EVENT } from "./fcl";

function CardEvents() {
  const {eventKey} = useParams()
  const [events, setEvents] = useState([])
  useEffect(
    () =>
      fcl.events(eventKey).subscribe((event) => {
        setEvents((oldEvents) => [event, ...oldEvents])
      }),
    [eventKey]
  )

  function cardCreated(card, index) {
    return (
      <div
      key={`${card.id}-${index}`}
      style={{
        border: "1px solid #ccc",
        borderRadius: "8px",
        padding: "1rem",
        margin: "1rem 0",
        backgroundColor: "#ccf",
      }}
    >
        <h2>Card Created: {card.id.toString()}</h2>
        <p>Name: {card.name}</p>
        <p>URL: {card.url}</p>
        <p>Attack: {card.attack}</p>
        <p>Health: {card.health}</p>
        <p>Level: {card.level}</p>
      </div>
    )
  }
  // Render each card event as a "box"
  return (
    <div style={{ padding: "1rem" }}>
      <h1>Card Events</h1>
      {events.map((event, index) => {
          switch (event.type) {
            case CARD_CREATED_EVENT:
              return cardCreated(event.data, index + 1000000000);
            default:
              return null;
          }
        })}
      {events.length === 0 && <p>No cards have been created yet.</p>}
    </div>
  );
}

export default CardEvents;
