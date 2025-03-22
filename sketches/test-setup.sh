#!/bin/bash

ALICE=179b6b1cb6755e31
CAROL=f3fcd2c1a78f5eee

expect -c "send 'alice'" \
| flow accounts create \
--network emulator \
--key 58dd308869aac654ffd49cf322883f862401ae8e6bf26dabc87cafde7c7bdedd5e248cf67d2480603f8f611f2e6200b3ead6c0dec00388e2569bc6c1714e78e2

expect -c "send 'carol'" \
| flow accounts create \
--network emulator \
--key 1ea5e2e6640073aff36dbe9a9f4fb5876adc80383d01947c0ab910da937cc324d02067712eec43c54842e83bf443731a61422995a9006c97f7c607f4b930e868

flow transactions send "cadence/transactions/transfer_flow.cdc" --signer emulator-account 1.0 $ALICE
flow transactions send "cadence/transactions/transfer_flow.cdc" --signer emulator-account 1.0 $CAROL

flow transactions send "cadence/transactions/setup_account.cdc" --signer alice
flow transactions send "cadence/transactions/setup_account.cdc" --signer carol
