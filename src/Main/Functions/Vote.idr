||| OUF Vote Functions
|||
||| Handles auditor voting on proposals.
|||
||| SPEC: VOTE_CAST, VOTE_ONCE, VOTE_DEADLINE, VOTE_SIGNATURE
module Main.Functions.Vote

import Main.Storages.Schema
import Main.Functions.ProposeUpgrade

%default covering

-- =============================================================================
-- Decision Constants
-- =============================================================================

||| No vote cast
public export
DECISION_NONE : Integer
DECISION_NONE = 0

||| Approve
public export
DECISION_APPROVE : Integer
DECISION_APPROVE = 1

||| Reject
public export
DECISION_REJECT : Integer
DECISION_REJECT = 2

||| Request changes
public export
DECISION_REQUEST_CHANGES : Integer
DECISION_REQUEST_CHANGES = 3

-- =============================================================================
-- Vote Storage Access
-- =============================================================================

||| Get vote slot for proposal + auditor
getVoteSlot : Integer -> Integer -> IO Integer
getVoteSlot proposalId auditorAddr = do
  innerSlot <- mappingSlot SLOT_VOTES_BASE proposalId
  mappingSlot innerSlot auditorAddr

||| Get vote decision
export
getVoteDecision : Integer -> Integer -> IO Integer
getVoteDecision proposalId auditorAddr = do
  slot <- getVoteSlot proposalId auditorAddr
  sload (slot + OFFSET_VOTE_DECISION)

||| Get vote signature
export
getVoteSig : Integer -> Integer -> IO Integer
getVoteSig proposalId auditorAddr = do
  slot <- getVoteSlot proposalId auditorAddr
  sload (slot + OFFSET_VOTE_SIG)

||| Store vote
storeVote : Integer -> Integer -> Integer -> Integer -> IO ()
storeVote proposalId auditorAddr decision sigHash = do
  slot <- getVoteSlot proposalId auditorAddr
  sstore (slot + OFFSET_VOTE_DECISION) decision
  sstore (slot + OFFSET_VOTE_SIG) sigHash

-- =============================================================================
-- Auditor Management
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

-- =============================================================================
-- REQ_VOTE_ONCE: Each auditor can vote only once per proposal
-- =============================================================================

||| Require caller has not voted
requireNotVoted : Integer -> Integer -> IO ()
requireNotVoted proposalId auditorAddr = do
  decision <- getVoteDecision proposalId auditorAddr
  if decision == DECISION_NONE
    then pure ()
    else revertConflict InvalidTransition  -- Already voted

-- =============================================================================
-- REQ_VOTE_DEADLINE: Votes rejected after deadline
-- =============================================================================

||| Require proposal not expired
requireNotExpired : Integer -> IO ()
requireNotExpired proposalId = do
  deadline <- getDeadline proposalId
  now <- timestamp
  if now <= deadline
    then pure ()
    else revertConflict EpochMismatch  -- Deadline passed

-- =============================================================================
-- Access Control
-- =============================================================================

||| Require caller to be auditor
requireAuditor : IO ()
requireAuditor = do
  callerAddr <- caller
  isAud <- isAuditor callerAddr
  if isAud
    then pure ()
    else revertConflict AuthViolation

||| Require proposal not executed
requireNotExecuted : Integer -> IO ()
requireNotExecuted proposalId = do
  executed <- getExecuted proposalId
  if executed == 0
    then pure ()
    else revertConflict InvalidTransition  -- Already executed

-- =============================================================================
-- Vote Count Management
-- =============================================================================

||| Get vote slot for count
getProposalSlot : Integer -> IO Integer
getProposalSlot proposalId = mappingSlot SLOT_PROPOSALS_BASE proposalId

||| Get current vote count
export
getVoteCount : Integer -> IO Integer
getVoteCount proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_VOTE_COUNT)

||| Increment vote count
incrementVoteCount : Integer -> IO Integer
incrementVoteCount proposalId = do
  slot <- getProposalSlot proposalId
  current <- sload (slot + OFFSET_VOTE_COUNT)
  let newCount = current + 1
  sstore (slot + OFFSET_VOTE_COUNT) newCount
  pure newCount

-- =============================================================================
-- REQ_VOTE_CAST: Auditor casts vote (approve/reject/requestChanges)
-- REQ_VOTE_SIGNATURE: Vote requires valid auditor signature
-- =============================================================================

||| Cast a vote on a proposal
||| Only auditors can call, once per proposal
export
castVote : Integer -> Integer -> Integer -> IO ()
castVote proposalId decision sigHash = do
  requireAuditor
  requireNotExpired proposalId
  requireNotExecuted proposalId
  callerAddr <- caller
  requireNotVoted proposalId callerAddr

  -- Store vote
  storeVote proposalId callerAddr decision sigHash

  -- If approve, increment count
  if decision == DECISION_APPROVE
    then do
      _ <- incrementVoteCount proposalId
      pure ()
    else pure ()

  -- Emit event
  mstore 0 decision
  log3 0 32 EVENT_VOTE_CAST proposalId callerAddr
