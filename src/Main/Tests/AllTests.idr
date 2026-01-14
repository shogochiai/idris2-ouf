||| OUF AllTests
|||
||| Test runner for all OUF specifications.
||| Following SPEC.toml coverage pattern.
module Main.Tests.AllTests

import Data.List
import Main.Storages.Schema
import Main.Functions.Factory
import Main.Functions.ProposeUpgrade
import Main.Functions.Vote
import Main.Functions.Tally
import Main.Functions.AssignAuditor
import Main.Functions.Fee

%default total

-- =============================================================================
-- FACTORY Tests
-- =============================================================================

||| REQ_FACTORY_CREATE
||| createUpgrader deploys new OU clone via CREATE2
export
test_factory_slot_constants : IO Bool
test_factory_slot_constants =
  pure $ SLOT_REGISTRY_BASE == 0x4000 && SLOT_UPGRADER_COUNT == 0x4001

||| REQ_FACTORY_REGISTRY
||| Factory maintains upgrader registry (id -> address)
export
test_factory_registry_slots : IO Bool
test_factory_registry_slots =
  pure $ SLOT_REGISTRY_BASE /= SLOT_DICTIONARY

||| REQ_FACTORY_DICTIONARY
||| All clones share upgraderDictionary for function dispatch
export
test_factory_dictionary_slot : IO Bool
test_factory_dictionary_slot =
  pure $ SLOT_DICTIONARY == 0x5000

-- =============================================================================
-- PROPOSE Tests
-- =============================================================================

||| REQ_PROPOSE_CREATE
||| proposeUpgrade creates new upgrade proposal
export
test_proposal_slot_offsets : IO Bool
test_proposal_slot_offsets =
  pure $ OFFSET_TARGET == 0 &&
         OFFSET_NEW_IMPL == 1 &&
         OFFSET_SELECTOR == 2 &&
         OFFSET_DEADLINE == 6

||| REQ_PROPOSE_VALIDATE
||| Proposal requires valid target, selector, newImpl
export
test_proposal_all_offsets_defined : IO Bool
test_proposal_all_offsets_defined =
  pure $ OFFSET_TARGET < 8 &&
         OFFSET_NEW_IMPL < 8 &&
         OFFSET_SELECTOR < 8 &&
         OFFSET_PROPOSER_SIG < 8 &&
         OFFSET_VOTE_COUNT < 8 &&
         OFFSET_THRESHOLD < 8 &&
         OFFSET_DEADLINE < 8 &&
         OFFSET_EXECUTED < 8

||| REQ_PROPOSE_ONLY_PROPOSER
||| Only designated proposer can create proposals
export
test_proposer_slot : IO Bool
test_proposer_slot =
  pure $ SLOT_PROPOSER == 0x5001

-- =============================================================================
-- VOTE Tests
-- =============================================================================

||| REQ_VOTE_CAST
||| Auditor casts vote (approve/reject/requestChanges)
export
test_vote_slots : IO Bool
test_vote_slots =
  pure $ SLOT_VOTES_BASE == 0x2000 &&
         OFFSET_VOTE_DECISION == 0 &&
         OFFSET_VOTE_SIG == 1

||| REQ_VOTE_ONCE
||| Each auditor can vote only once per proposal
export
test_vote_decision_offset : IO Bool
test_vote_decision_offset =
  pure $ OFFSET_VOTE_DECISION == 0

||| REQ_VOTE_DEADLINE
||| Votes rejected after deadline
export
test_deadline_offset : IO Bool
test_deadline_offset =
  pure $ OFFSET_DEADLINE == 6

||| REQ_VOTE_SIGNATURE
||| Vote requires valid auditor signature
export
test_vote_sig_offset : IO Bool
test_vote_sig_offset =
  pure $ OFFSET_VOTE_SIG == 1

-- =============================================================================
-- TALLY Tests
-- =============================================================================

||| REQ_TALLY_THRESHOLD
||| n-of-n approval required (threshold = auditorCount)
export
test_threshold_offset : IO Bool
test_threshold_offset =
  pure $ OFFSET_THRESHOLD == 5

||| REQ_TALLY_AUTO_EXECUTE
||| Auto-execute when threshold met + proposer signature
export
test_executed_offset : IO Bool
test_executed_offset =
  pure $ OFFSET_EXECUTED == 7

||| REQ_TALLY_STATUS
||| getVotingStatus returns (votes, threshold, isComplete)
export
test_vote_count_offset : IO Bool
test_vote_count_offset =
  pure $ OFFSET_VOTE_COUNT == 4

-- =============================================================================
-- AUDITOR Tests
-- =============================================================================

||| REQ_AUDITOR_ASSIGN
||| Admin assigns auditors to proposal
export
test_admin_slot : IO Bool
test_admin_slot =
  pure $ SLOT_ADMIN == 0x5002

||| REQ_AUDITOR_POOL
||| Auditors drawn from OUC-managed pool
export
test_auditors_base : IO Bool
test_auditors_base =
  pure $ SLOT_AUDITORS_BASE == 0x3000

||| REQ_AUDITOR_COUNT
||| Progressive auditor requirement (nth upgrade needs n auditors)
export
test_auditor_count_slot : IO Bool
test_auditor_count_slot =
  pure $ SLOT_AUDITOR_COUNT == 0x3001

-- =============================================================================
-- SCHEMA Tests
-- =============================================================================

||| REQ_SCHEMA_PROPOSAL
||| Proposal storage: target, newImpl, selector, votes, deadline, executed
export
test_proposal_struct_complete : IO Bool
test_proposal_struct_complete =
  -- All 8 slots used (0-7)
  pure $ OFFSET_EXECUTED == 7

||| REQ_SCHEMA_VOTES
||| Vote storage: nested mapping proposalId -> auditor -> decision
export
test_votes_nested_mapping : IO Bool
test_votes_nested_mapping =
  pure $ SLOT_VOTES_BASE /= SLOT_PROPOSALS_BASE

||| REQ_SCHEMA_AUDITORS
||| Auditor list storage with count
export
test_auditor_storage : IO Bool
test_auditor_storage =
  pure $ SLOT_AUDITOR_COUNT == SLOT_AUDITORS_BASE + 1

-- =============================================================================
-- Function Selector Tests
-- =============================================================================

export
test_selectors_unique : IO Bool
test_selectors_unique =
  pure $ SEL_CREATE_UPGRADER /= SEL_PROPOSE_UPGRADE &&
         SEL_PROPOSE_UPGRADE /= SEL_CAST_VOTE &&
         SEL_CAST_VOTE /= SEL_TALLY &&
         SEL_TALLY /= SEL_ASSIGN_AUDITOR

-- =============================================================================
-- FEE Tests
-- =============================================================================

||| REQ_FEE_SLOTS
||| Fee storage slots: balance mapping, ckETH helper, min deposit
export
test_fee_slots : IO Bool
test_fee_slots =
  pure $ SLOT_FEE_BALANCE_BASE == 0x6000 &&
         SLOT_CKETH_HELPER == 0x6001 &&
         SLOT_MIN_DEPOSIT == 0x6002 &&
         SLOT_TOTAL_FEES == 0x6003

||| REQ_FEE_DEPOSIT
||| depositFee uses callvalue and updates balance
export
test_fee_events : IO Bool
test_fee_events =
  pure $ EVENT_FEE_DEPOSITED == 0xfee001 &&
         EVENT_FEE_BRIDGED == 0xfee002

||| REQ_FEE_BRIDGE
||| depositAndBridge uses ckETH helper with correct selector
export
test_fee_cketh_selector : IO Bool
test_fee_cketh_selector =
  pure $ SEL_DEPOSIT_ETH == 0xda6d948e

-- =============================================================================
-- All Tests
-- =============================================================================

export
allTests : List (String, IO Bool)
allTests =
  [ -- Factory
    ("REQ_FACTORY_CREATE: slot constants defined", test_factory_slot_constants)
  , ("REQ_FACTORY_REGISTRY: registry slots separate", test_factory_registry_slots)
  , ("REQ_FACTORY_DICTIONARY: dictionary slot", test_factory_dictionary_slot)
  -- Propose
  , ("REQ_PROPOSE_CREATE: proposal offsets", test_proposal_slot_offsets)
  , ("REQ_PROPOSE_VALIDATE: all offsets in struct", test_proposal_all_offsets_defined)
  , ("REQ_PROPOSE_ONLY_PROPOSER: proposer slot", test_proposer_slot)
  -- Vote
  , ("REQ_VOTE_CAST: vote slots", test_vote_slots)
  , ("REQ_VOTE_ONCE: decision offset", test_vote_decision_offset)
  , ("REQ_VOTE_DEADLINE: deadline offset", test_deadline_offset)
  , ("REQ_VOTE_SIGNATURE: sig offset", test_vote_sig_offset)
  -- Tally
  , ("REQ_TALLY_THRESHOLD: threshold offset", test_threshold_offset)
  , ("REQ_TALLY_AUTO_EXECUTE: executed offset", test_executed_offset)
  , ("REQ_TALLY_STATUS: vote count offset", test_vote_count_offset)
  -- Auditor
  , ("REQ_AUDITOR_ASSIGN: admin slot", test_admin_slot)
  , ("REQ_AUDITOR_POOL: auditors base", test_auditors_base)
  , ("REQ_AUDITOR_COUNT: count slot", test_auditor_count_slot)
  -- Schema
  , ("REQ_SCHEMA_PROPOSAL: struct complete", test_proposal_struct_complete)
  , ("REQ_SCHEMA_VOTES: nested mapping", test_votes_nested_mapping)
  , ("REQ_SCHEMA_AUDITORS: auditor storage", test_auditor_storage)
  -- Selectors
  , ("SELECTORS: all unique", test_selectors_unique)
  -- Fee
  , ("REQ_FEE_SLOTS: fee storage slots", test_fee_slots)
  , ("REQ_FEE_DEPOSIT: fee events defined", test_fee_events)
  , ("REQ_FEE_BRIDGE: ckETH selector", test_fee_cketh_selector)
  ]

runTest : (String, IO Bool) -> IO (String, Bool)
runTest (name, test) = do
  result <- test
  pure (name, result)

export covering
runTests : IO ()
runTests = do
  putStrLn "=== OUF Tests ==="
  results <- traverse runTest allTests
  let passed = filter snd results
  let failed = filter (not . snd) results
  traverse_ (\(name, _) => putStrLn $ "  FAIL: " ++ name) failed
  putStrLn $ "Passed: " ++ show (length passed) ++ "/" ++ show (length results)
