||| OUF Tally Functions
|||
||| Tallies votes and executes upgrades when threshold met.
|||
||| SPEC: TALLY_THRESHOLD, TALLY_AUTO_EXECUTE, TALLY_STATUS
module Main.Functions.Tally

import Main.Storages.Schema
import Main.Functions.ProposeUpgrade
import Main.Functions.Vote

%default covering

-- =============================================================================
-- Proposer Signature
-- =============================================================================

||| Get proposal slot
getProposalSlot : Integer -> IO Integer
getProposalSlot proposalId = mappingSlot SLOT_PROPOSALS_BASE proposalId

||| Get proposer signature
export
getProposerSig : Integer -> IO Integer
getProposerSig proposalId = do
  slot <- getProposalSlot proposalId
  sload (slot + OFFSET_PROPOSER_SIG)

||| Set proposer signature
setProposerSig : Integer -> Integer -> IO ()
setProposerSig proposalId sigHash = do
  slot <- getProposalSlot proposalId
  sstore (slot + OFFSET_PROPOSER_SIG) sigHash

||| Set executed flag
setExecuted : Integer -> IO ()
setExecuted proposalId = do
  slot <- getProposalSlot proposalId
  sstore (slot + OFFSET_EXECUTED) 1

-- =============================================================================
-- REQ_TALLY_STATUS: getVotingStatus returns (votes, threshold, isComplete)
-- =============================================================================

||| Get voting status
||| Returns (currentVotes, requiredVotes, isComplete)
export
getVotingStatus : Integer -> IO (Integer, Integer, Integer)
getVotingStatus proposalId = do
  currentVotes <- getVoteCount proposalId
  threshold <- getThreshold proposalId
  proposerSig <- getProposerSig proposalId
  executed <- getExecuted proposalId

  let isComplete = if currentVotes >= threshold && proposerSig /= 0 && executed == 0
                     then 1
                     else 0
  pure (currentVotes, threshold, isComplete)

||| Check if voting is complete
export
isVotingComplete : Integer -> IO Bool
isVotingComplete proposalId = do
  (_, _, isComplete) <- getVotingStatus proposalId
  pure (isComplete == 1)

||| Check if proposal is executed
export
isExecuted : Integer -> IO Bool
isExecuted proposalId = do
  executed <- getExecuted proposalId
  pure (executed /= 0)

-- =============================================================================
-- REQ_TALLY_THRESHOLD: n-of-n approval required
-- =============================================================================

||| Check if threshold is met
export
thresholdMet : Integer -> IO Bool
thresholdMet proposalId = do
  currentVotes <- getVoteCount proposalId
  threshold <- getThreshold proposalId
  pure (currentVotes >= threshold)

-- =============================================================================
-- REQ_TALLY_AUTO_EXECUTE: Auto-execute when threshold met + proposer signature
-- =============================================================================

mutual
  ||| Execute the upgrade on Dictionary
  ||| Internal: called when all conditions met
  executeUpgrade : Integer -> IO ()
  executeUpgrade proposalId = do
    -- Mark as executed first (reentrancy protection)
    setExecuted proposalId

    -- Get proposal data
    target <- getTarget proposalId
    newImpl <- getNewImpl proposalId
    selector <- getProposalSelector proposalId

    -- Get Dictionary address
    dictAddr <- sload SLOT_DICTIONARY

    -- Build calldata for Dictionary.setImplementation(selector, impl)
    -- selector: 0x2c3c3e4e (SEL_SET_IMPL)
    mstore 0 0x2c3c3e4e
    mstore 4 selector
    mstore 36 newImpl

    -- Call Dictionary
    success <- call 100000 dictAddr 0 0 68 0 0

    if success /= 0
      then do
        -- Emit success event
        mstore 0 newImpl
        log2 0 32 EVENT_UPGRADE_EXECUTED proposalId
      else revertConflict ExternalCallForbidden  -- Dictionary call failed

  ||| Try to execute upgrade if conditions met
  ||| Called after each vote and proposer sig submission
  export
  tryExecuteUpgrade : Integer -> IO ()
  tryExecuteUpgrade proposalId = do
    (_, _, isComplete) <- getVotingStatus proposalId
    if isComplete == 1
      then executeUpgrade proposalId
      else pure ()

||| Submit proposer signature
||| Required for execution
export
submitProposerSignature : Integer -> Integer -> IO ()
submitProposerSignature proposalId sigHash = do
  requireProposer

  -- Check not executed
  executed <- getExecuted proposalId
  if executed /= 0
    then revertConflict InvalidTransition  -- Already executed
    else do
      -- Check not already submitted
      existingSig <- getProposerSig proposalId
      if existingSig /= 0
        then revertConflict InvalidTransition  -- Already submitted
        else do
          setProposerSig proposalId sigHash
          -- Check if ready to execute
          tryExecuteUpgrade proposalId

||| Manual tally (can be called by anyone)
||| Checks conditions and executes if ready
export
tally : Integer -> IO ()
tally proposalId = tryExecuteUpgrade proposalId
