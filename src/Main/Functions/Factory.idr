||| OUF Factory Functions
|||
||| Creates new OU (OptimisticUpgrader) clones via CREATE2.
||| Maintains registry of all deployed upgraders.
|||
||| SPEC: FACTORY_CREATE, FACTORY_REGISTRY, FACTORY_DICTIONARY
module Main.Functions.Factory

import Main.Storages.Schema
import Subcontract.Std.Functions.ProxyFactory

%default covering

-- =============================================================================
-- REQ_FACTORY_CREATE: createUpgrader deploys new OU clone via CREATE2
-- =============================================================================

||| Get the next upgrader ID
export
getUpgraderCount : IO Integer
getUpgraderCount = sload SLOT_UPGRADER_COUNT

||| Set upgrader count
export
setUpgraderCount : Integer -> IO ()
setUpgraderCount count = sstore SLOT_UPGRADER_COUNT count

||| Get shared Dictionary address
export
getDictionary : IO Integer
getDictionary = sload SLOT_DICTIONARY

||| Set shared Dictionary address (admin only, during init)
export
setDictionary : Integer -> IO ()
setDictionary addr = sstore SLOT_DICTIONARY addr

-- =============================================================================
-- REQ_FACTORY_REGISTRY: Factory maintains upgrader registry
-- =============================================================================

||| Get upgrader address by ID
export
getUpgrader : Integer -> IO Integer
getUpgrader upgraderId = do
  -- slot = keccak256(upgraderId . SLOT_REGISTRY_BASE)
  slot <- mappingSlot SLOT_REGISTRY_BASE upgraderId
  sload slot

||| Register new upgrader
export
registerUpgrader : Integer -> Integer -> IO ()
registerUpgrader upgraderId addr = do
  slot <- mappingSlot SLOT_REGISTRY_BASE upgraderId
  sstore slot addr

-- =============================================================================
-- REQ_FACTORY_DICTIONARY: All clones share upgraderDictionary
-- =============================================================================

||| Create new OU clone
||| Uses CREATE2 with upgraderId as salt for deterministic addresses
||| Deploys ERC-7546 Proxy pointing to shared Dictionary
export
createUpgrader : IO Integer
createUpgrader = do
  -- Get next ID (used as salt for CREATE2)
  upgraderId <- getUpgraderCount

  -- Get shared Dictionary address
  dictAddr <- getDictionary

  -- Deploy ERC-7546 Proxy via CREATE2
  -- deployProxy stores dictionary in DICTIONARY_SLOT and returns proxy address
  newAddr <- deployProxy dictAddr upgraderId

  -- Register in registry
  registerUpgrader upgraderId newAddr

  -- Increment counter
  setUpgraderCount (upgraderId + 1)

  -- Emit event
  mstore 0 newAddr
  log2 0 32 EVENT_UPGRADER_CREATED upgraderId

  pure newAddr

-- =============================================================================
-- Admin Functions
-- =============================================================================

||| Get admin address
export
getAdmin : IO Integer
getAdmin = sload SLOT_ADMIN

||| Require caller to be admin
export
requireAdmin : IO ()
requireAdmin = do
  admin <- getAdmin
  callerAddr <- caller
  if admin == callerAddr
    then pure ()
    else revertConflict AuthViolation

||| Initialize factory (admin only, once)
export
initFactory : Integer -> Integer -> IO ()
initFactory dictAddr adminAddr = do
  -- Check not already initialized
  currentDict <- getDictionary
  if currentDict /= 0
    then revertConflict InitAlready
    else do
      setDictionary dictAddr
      sstore SLOT_ADMIN adminAddr
