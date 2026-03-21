// This target exists to force SwiftPM to make OpenUSD visible to Deconstructed targets that
// rely on the public USDInterop package family (`USDInterfaces`, `USDInteropCxx`, `USDOperations`)
// without leaking OpenUSD imports across feature modules.

import OpenUSD
import USDInterfaces
import USDInteropCxx
