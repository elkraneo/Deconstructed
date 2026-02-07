// This target exists to force SwiftPM to make OpenUSD visible to Deconstructed targets that
// import USDInteropAdvanced *binary* frameworks (whose modules reference OpenUSD types).

import OpenUSD
import USDInterfaces
import USDInteropCxx
