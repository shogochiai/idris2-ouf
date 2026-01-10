||| OUF Auditor Assignment Functions
|||
||| Manages auditor assignment to proposals.
|||
||| SPEC: AUDITOR_ASSIGN, AUDITOR_POOL, AUDITOR_COUNT
module Main.Functions.AssignAuditor

import Main.Storages.Schema
import Main.Functions.Factory

%default covering

-- =============================================================================
-- Auditor Storage Access
-- =============================================================================

||| Get auditor slot by index
getAuditorSlot : Integer -> IO Integer
getAuditorSlot idx = mappingSlot SLOT_AUDITORS_BASE idx

||| Get auditor address by index
export
getAuditorAddr : Integer -> IO Integer
getAuditorAddr idx = do
  slot <- getAuditorSlot idx
  sload slot

||| Get auditor count
export
getAuditorCount : IO Integer
getAuditorCount = sload SLOT_AUDITOR_COUNT

||| Set auditor count
setAuditorCount : Integer -> IO ()
setAuditorCount count = sstore SLOT_AUDITOR_COUNT count

-- =============================================================================
-- REQ_AUDITOR_ASSIGN: Admin assigns auditors to proposal
-- =============================================================================

||| Add auditor to list (admin only)
export
addAuditor : Integer -> IO Integer
addAuditor auditorAddr = do
  requireAdmin
  idx <- getAuditorCount
  slot <- getAuditorSlot idx
  sstore slot auditorAddr
  setAuditorCount (idx + 1)
  pure idx

||| Remove auditor from list (admin only)
||| Swaps with last element and decrements count
export
removeAuditor : Integer -> IO ()
removeAuditor idx = do
  requireAdmin
  count <- getAuditorCount
  if idx >= count
    then revertConflict DecodeError  -- Invalid index
    else do
      -- If not last, swap with last
      if idx /= count - 1
        then do
          lastSlot <- getAuditorSlot (count - 1)
          lastAddr <- sload lastSlot
          slot <- getAuditorSlot idx
          sstore slot lastAddr
        else pure ()
      -- Decrement count
      setAuditorCount (count - 1)

-- =============================================================================
-- REQ_AUDITOR_POOL: Auditors drawn from OUC-managed pool
-- =============================================================================

||| Check if address is auditor
export
isAuditor : Integer -> IO Bool
isAuditor addr = do
  count <- getAuditorCount
  checkLoop addr 0 count
  where
    checkLoop : Integer -> Integer -> Integer -> IO Bool
    checkLoop target idx cnt =
      if idx >= cnt
        then pure False
        else do
          auditorAddr <- getAuditorAddr idx
          if auditorAddr == target
            then pure True
            else checkLoop target (idx + 1) cnt

||| Get all auditors
export
getAllAuditors : IO (List Integer)
getAllAuditors = do
  count <- getAuditorCount
  collectLoop 0 count []
  where
    collectLoop : Integer -> Integer -> List Integer -> IO (List Integer)
    collectLoop idx cnt acc =
      if idx >= cnt
        then pure (reverse acc)
        else do
          addr <- getAuditorAddr idx
          collectLoop (idx + 1) cnt (addr :: acc)

-- =============================================================================
-- REQ_AUDITOR_COUNT: Progressive auditor requirement
-- =============================================================================

||| Calculate required auditor count for nth upgrade
||| Progressive: nth upgrade needs n auditors (capped at pool size)
export
requiredAuditorsForUpgrade : Integer -> IO Integer
requiredAuditorsForUpgrade upgradeNumber = do
  poolSize <- getAuditorCount
  pure $ min poolSize upgradeNumber
  where
    min : Integer -> Integer -> Integer
    min a b = if a < b then a else b

-- =============================================================================
-- Batch Operations
-- =============================================================================

||| Initialize auditor pool (admin only, during setup)
export
initAuditorPool : List Integer -> IO ()
initAuditorPool addrs = do
  requireAdmin
  -- Check not already initialized
  currentCount <- getAuditorCount
  if currentCount /= 0
    then revertConflict InitAlready
    else do
      -- Add all auditors
      addAll addrs 0
      setAuditorCount (cast $ length addrs)
  where
    addAll : List Integer -> Integer -> IO ()
    addAll [] _ = pure ()
    addAll (addr :: rest) idx = do
      slot <- getAuditorSlot idx
      sstore slot addr
      addAll rest (idx + 1)
