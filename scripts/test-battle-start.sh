#!/bin/bash

ALICE=179b6b1cb6755e31
CAROL=f3fcd2c1a78f5eee


ALICE_CARDS=$(flow scripts execute cadence/scripts/list_cards.cdc $ALICE | cut -d ':' -f 2)
CAROL_CARDS=$(flow scripts execute cadence/scripts/list_cards.cdc $CAROL | cut -d ':' -f 2)


flow transactions send "cadence/transactions/start_battle.cdc" --proposer alice --payer carol --authorizer alice,carol "${ALICE_CARDS}" "${CAROL_CARDS}"