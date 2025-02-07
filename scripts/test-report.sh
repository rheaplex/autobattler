#!/bin/bash

EMORY=f8d6e0586b0a20c7
ALICE=179b6b1cb6755e31
CAROL=f3fcd2c1a78f5eee

echo ALICE:
flow scripts execute "cadence/scripts/report.cdc" $ALICE

echo CAROL:
flow scripts execute "cadence/scripts/report.cdc" $CAROL
