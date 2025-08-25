//--------------------------------------------------------------------
// TOY PRNG
//--------------------------------------------------------------------

// DO NOT USE THIS IN PRODUCTION

access (all) contract ToyPRNG {

    // https://en.wikipedia.org/wiki/Xorshift
    access(all) struct Xorshift64 {
        access(self) var state: UInt64

        init(seed: UInt64, salt: UInt64) {
            self.state = seed ^ salt
        }

        access(contract) fun nextUInt64(): UInt64 {
            var x = self.state
            x = x ^ (x << 13)
            x = x ^ (x >> 7)
            x = x ^ (x << 17)
            self.state = x
            return x
        }
    }

}
