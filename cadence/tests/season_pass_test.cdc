import Test
import BlockchainHelpers
import "test_helpers.cdc"

access(all) let autobattler = Test.getAccount(0x0000000000000007)
access(all) let characters = Test.createAccount()
access(all) let season = Test.createAccount()
access(all) let player = Test.createAccount()


access(all) fun testSetup() {
    deploy("ToyPRNG", "../contracts/ToyPRNG.cdc")
    deploy("AutoBattler", "../contracts/AutoBattler.cdc")

    var _ = txExecutor(
        "../transactions/setup_battleballs_characters.cdc",
        [characters],
        // This is the account that Test deploys to.
        [autobattler.address],
        nil,
        nil
    )
   _ = txExecutor(
        "../transactions/setup_battleballs_season.cdc",
        [season],
        [characters.address],
        nil,
        nil
    )
    _ = txExecutor(
        "../transactions/transfer_tokens.cdc",
        [Test.serviceAccount()],
        [20.0, player.address],
        nil,
        nil
    )
}

access(all) fun testPurchasePass () {
    let success: Bool = txExecutor(
            "../transactions/purchase_pass.cdc",
            [player],
            [season.address, /public/PurchaseBattleBallsPass, /storage/BattleBallsPass],
            nil,
            nil
        )
    Test.assertEqual(true, success)
}

access(all) fun testBuyCharacters () {
    let success: Bool = txExecutor(
        "../transactions/buy_characters.cdc",
        [player],
        [/storage/BattleBallsPass, [1 as UInt64, 2 as UInt64, 3 as UInt64]],
        nil,
        nil
    )
    Test.assertEqual(true, success)
}

access(all) fun testAssembleTeam () {
    let success: Bool = txExecutor(
        "../transactions/assemble_team.cdc",
        [player],
        [/storage/BattleBallsPass, [0 as UInt64, 1 as UInt64, 2 as UInt64]],
        nil,
        nil
    )
    Test.assertEqual(true, success)
}

access(all) fun testStartBattle() {
    let success: Bool = txExecutor(
            "../transactions/start_battle.cdc",
            [player],
            [/storage/BattleBallsPass],
            nil,
            nil
        )
    Test.assertEqual(true, success)
}

access(all) fun testEndBattle() {
    let success = txExecutor(
            "../transactions/end_battle.cdc",
            [player],
            [/storage/BattleBallsPass, 0 as UInt64],
            nil,
            nil
        )
    Test.assertEqual(true, success)
}
