||| OUF Proposal Functions
|||
||| Creates and manages upgrade proposals.
|||
||| SPEC: PROPOSE_CREATE, PROPOSE_VALIDATE, PROPOSE_ONLY_PROPOSER
module Main.Functions.ProposeUpgrade

import Main.Storages.Schema

%default covering

-- =============================================================================
-- Storage Access
-- =============================================================================

||| Get proposer address
export
getProposer : IO Integer
getProposer = sload SLOT_PROPOSER

||| Set proposer address
export
setProposer : Integer -> IO ()
setProposer addr = sstore SLOT_PROPOSER addr

||| Get proposal slot
getProposalSlot : Integer -> IO Integer
getProposalSlot proposalId = mappingSlot SLOT_PROPOSALS_BASE proposalId

||| Get proposal target
export
getTarget : Integer -> IO Integer
getTarget proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_TARGET)

||| Get proposal new implementation
export
getNewImpl : Integer -> IO Integer
getNewImpl proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_NEW_IMPL)

||| Get proposal selector
export
getProposalSelector : Integer -> IO Integer
getProposalSelector proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_SELECTOR)

||| Get proposal deadline
export
getDeadline : Integer -> IO Integer
getDeadline proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_DEADLINE)

||| Get proposal threshold
export
getThreshold : Integer -> IO Integer
getThreshold proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_THRESHOLD)

||| Get executed flag
export
getExecuted : Integer -> IO Integer
getExecuted proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_EXECUTED)

-- =============================================================================
-- REQ_PROPOSE_ONLY_PROPOSER: Only designated proposer can create proposals
-- =============================================================================

||| Require caller to be proposer
export
requireProposer : IO ()
requireProposer = do
  proposer <- getProposer
  callerAddr <- caller
  if proposer == callerAddr
    then pure ()
    else revertConflict AuthViolation

-- =============================================================================
-- REQ_PROPOSE_VALIDATE: Proposal requires valid target, selector, newImpl
-- =============================================================================

||| Validate proposal parameters
validateProposal : Integer -> Integer -> Integer -> Integer -> IO Bool
validateProposal target newImpl selector deadline = do
  now <- timestamp
  pure $ target /= 0 && newImpl /= 0 && selector /= 0 && deadline > now

-- =============================================================================
-- REQ_PROPOSE_CREATE: proposeUpgrade creates new upgrade proposal
-- =============================================================================

||| Store proposal data
storeProposal : Integer -> Integer -> Integer -> Integer -> Integer -> Integer -> IO ()
storeProposal proposalId target newImpl selector threshold deadline = do
  slot <- getProposalSlot proposalId
  sstore (slot + OFFSET_TARGET) target
  sstore (slot + OFFSET_NEW_IMPL) newImpl
  sstore (slot + OFFSET_SELECTOR) selector
  sstore (slot + OFFSET_PROPOSER_SIG) 0
  sstore (slot + OFFSET_VOTE_COUNT) 0
  sstore (slot + OFFSET_THRESHOLD) threshold
  sstore (slot + OFFSET_DEADLINE) deadline
  sstore (slot + OFFSET_EXECUTED) 0

||| Create a new upgrade proposal
||| Only proposer can call
export
proposeUpgrade : Integer -> Integer -> Integer -> Integer -> Integer -> IO ()
proposeUpgrade proposalId target newImpl selector deadline = do
  requireProposer

  -- Validate inputs
  isValid <- validateProposal target newImpl selector deadline
  if not isValid
    then revertConflict DecodeError  -- Invalid proposal params
    else do
      -- Get auditor count for threshold (n-of-n)
      auditorCount <- sload SLOT_AUDITOR_COUNT
      if auditorCount == 0
        then revertConflict NotInitialized  -- Need at least one auditor
        else do
          storeProposal proposalId target newImpl selector auditorCount deadline

          -- Emit event
          mstore 0 target
          mstore 32 newImpl
          log2 0 64 EVENT_PROPOSAL_CREATED proposalId

||| Check if proposal exists
export
proposalExists : Integer -> IO Bool
proposalExists proposalId = do
  threshold <- getThreshold proposalId
  pure (threshold /= 0)
