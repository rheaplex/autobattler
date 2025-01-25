// Sketch for incorporation into the main contract.

// Default rating for players is not 0. 1500.0?

access(all) contract Elo {

    // Naive, slow, buggy.
    access(all) fun pow(n: Fix64, x: Fix64): Fix64 {
        var result: Fix64 = 0.0
        var count: Fix64 = 0.0
        while count < x {
            result = result * n
            count = count + 1.0
        }
        return result
    }

    access(all) fun expected(a: Fix64, b: Fix64): Fix64 {
        var exponent: Fix64 = (b - a) / 400.0
        return 1.0 / (1.0 + (self.pow(n: 10.0, x: exponent))
    }

    // Untested.
    access (all) fun elo(
        winnerRank: Fix64,
        loserRank: Fix64,
        k: Fix64
    ): [Fix64] {
        var aExpected: Fix64 = self.expected(a: winnerRank, b: loserRank)
        var bExpected: Fix64 = self.expected(a: loserRank, b: winnerRank)
        var winnerNewRank: Fix64 = winnerRank + k * (1.0 - aExpected)
        var loserNewRank: Fix64 = loserRank + k * (1.0 - bExpected)
        return [winnerNewRank, loserNewRank]
    }

}
