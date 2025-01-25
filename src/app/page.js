"use client";

import { configFCL } from "./fcl";
import BattleEvents from "./battle";
import CardEvents from "./cards";

export default function Home() {
  configFCL();
  return (
    <div>
      <BattleEvents />
      <CardEvents />
    </div>
  );
}
