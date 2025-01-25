#!/bin/bash

ALICE=179b6b1cb6755e31
CAROL=f3fcd2c1a78f5eee

flow transactions send "cadence/transactions/advance_battle.cdc" --proposer alice --payer carol --authorizer alice,carol