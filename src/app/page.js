"use client";

import Image from "next/image";
import BattleEvents from "./battle";

const BATTLE_CREATED_EVENT = "A.0xSUPER.SuperAutoPets.BattleCreated";

export default function Home() {
  return (
    <div>
      <BattleEvents />
    </div>
  );
}
