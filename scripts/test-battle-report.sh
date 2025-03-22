#!/bin/bash

EMORY=f8d6e0586b0a20c7
ALICE=179b6b1cb6755e31
CAROL=f3fcd2c1a78f5eee

# 9 is ..len(Result: )

flow scripts execute --log debug "cadence/scripts/get_battle_replay.cdc" $EMORY \
    | tail -c +10 \
    | sed 's/", "/\n/g' \
    | sed 's/\["//g' \
    | sed 's/"\]//g' \
    | sed 's/\] /\]\n    /g' \
    | sed 's/\},/\}\n            /g'
