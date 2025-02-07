AutoGame
========

Details forthcoming.

Front end code: JS via bun.

Smart Contracts: Cadence via flow.

Console one:
```
flow emulator
```

Console two:
```
flow project deploy
flow dev-wallet
```

Console three:
```
bash scripts/test-setup.sh &&\
bash scripts/test-domain-create.sh &&\
bash scripts/test-run-start.sh &&\
bash scripts/test-battle-start.sh &&\
bash scripts/test-report.sh &&\
bash scripts/test-battle-finish.sh &&\
bash scripts/test-report.sh &&\
bash scripts/test-battle-result.sh
```