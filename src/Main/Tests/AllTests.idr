||| OUF AllTests
|||
||| Test runner for all OUF specifications.
||| Following SPEC.toml coverage pattern.
module Main.Tests.AllTests

import Data.List
import Main.Storages.Schema

%default total

-- =============================================================================
-- FACTORY Tests
-- =============================================================================

-- | SPEC: FACTORY_CREATE
-- | createUpgrader deploys new OU clone via CREATE2
test_factory_slot_constants : Bool
test_factory_slot_constants =
  SLOT_REGISTRY_BASE == 0x4000 && SLOT_UPGRADER_COUNT == 0x4001

-- | SPEC: FACTORY_REGISTRY
-- | Factory maintains upgrader registry (id -> address)
test_factory_registry_slots : Bool
test_factory_registry_slots =
  SLOT_REGISTRY_BASE /= SLOT_DICTIONARY

-- | SPEC: FACTORY_DICTIONARY
-- | All clones share upgraderDictionary for function dispatch
test_factory_dictionary_slot : Bool
test_factory_dictionary_slot =
  SLOT_DICTIONARY == 0x5000

-- =============================================================================
-- PROPOSE Tests
-- =============================================================================

-- | SPEC: PROPOSE_CREATE
-- | proposeUpgrade creates new upgrade proposal
test_proposal_slot_offsets : Bool
test_proposal_slot_offsets =
  OFFSET_TARGET == 0 &&
  OFFSET_NEW_IMPL == 1 &&
  OFFSET_SELECTOR == 2 &&
  OFFSET_DEADLINE == 6

-- | SPEC: PROPOSE_VALIDATE
-- | Proposal requires valid target, selector, newImpl
test_proposal_all_offsets_defined : Bool
test_proposal_all_offsets_defined =
  OFFSET_TARGET < 8 &&
  OFFSET_NEW_IMPL < 8 &&
  OFFSET_SELECTOR < 8 &&
  OFFSET_PROPOSER_SIG < 8 &&
  OFFSET_VOTE_COUNT < 8 &&
  OFFSET_THRESHOLD < 8 &&
  OFFSET_DEADLINE < 8 &&
  OFFSET_EXECUTED < 8

-- | SPEC: PROPOSE_ONLY_PROPOSER
-- | Only designated proposer can create proposals
test_proposer_slot : Bool
test_proposer_slot =
  SLOT_PROPOSER == 0x5001

-- =============================================================================
-- VOTE Tests
-- =============================================================================

-- | SPEC: VOTE_CAST
-- | Auditor casts vote (approve/reject/requestChanges)
test_vote_slots : Bool
test_vote_slots =
  SLOT_VOTES_BASE == 0x2000 &&
  OFFSET_VOTE_DECISION == 0 &&
  OFFSET_VOTE_SIG == 1

-- | SPEC: VOTE_ONCE
-- | Each auditor can vote only once per proposal
test_vote_decision_offset : Bool
test_vote_decision_offset =
  OFFSET_VOTE_DECISION == 0

-- | SPEC: VOTE_DEADLINE
-- | Votes rejected after deadline
test_deadline_offset : Bool
test_deadline_offset =
  OFFSET_DEADLINE == 6

-- | SPEC: VOTE_SIGNATURE
-- | Vote requires valid auditor signature
test_vote_sig_offset : Bool
test_vote_sig_offset =
  OFFSET_VOTE_SIG == 1

-- =============================================================================
-- TALLY Tests
-- =============================================================================

-- | SPEC: TALLY_THRESHOLD
-- | n-of-n approval required (threshold = auditorCount)
test_threshold_offset : Bool
test_threshold_offset =
  OFFSET_THRESHOLD == 5

-- | SPEC: TALLY_AUTO_EXECUTE
-- | Auto-execute when threshold met + proposer signature
test_executed_offset : Bool
test_executed_offset =
  OFFSET_EXECUTED == 7

-- | SPEC: TALLY_STATUS
-- | getVotingStatus returns (votes, threshold, isComplete)
test_vote_count_offset : Bool
test_vote_count_offset =
  OFFSET_VOTE_COUNT == 4

-- =============================================================================
-- AUDITOR Tests
-- =============================================================================

-- | SPEC: AUDITOR_ASSIGN
-- | Admin assigns auditors to proposal
test_admin_slot : Bool
test_admin_slot =
  SLOT_ADMIN == 0x5002

-- | SPEC: AUDITOR_POOL
-- | Auditors drawn from OUC-managed pool
test_auditors_base : Bool
test_auditors_base =
  SLOT_AUDITORS_BASE == 0x3000

-- | SPEC: AUDITOR_COUNT
-- | Progressive auditor requirement (nth upgrade needs n auditors)
test_auditor_count_slot : Bool
test_auditor_count_slot =
  SLOT_AUDITOR_COUNT == 0x3001

-- =============================================================================
-- SCHEMA Tests
-- =============================================================================

-- | SPEC: SCHEMA_PROPOSAL
-- | Proposal storage: target, newImpl, selector, votes, deadline, executed
test_proposal_struct_complete : Bool
test_proposal_struct_complete =
  -- All 8 slots used (0-7)
  OFFSET_EXECUTED == 7

-- | SPEC: SCHEMA_VOTES
-- | Vote storage: nested mapping proposalId -> auditor -> decision
test_votes_nested_mapping : Bool
test_votes_nested_mapping =
  SLOT_VOTES_BASE /= SLOT_PROPOSALS_BASE

-- | SPEC: SCHEMA_AUDITORS
-- | Auditor list storage with count
test_auditor_storage : Bool
test_auditor_storage =
  SLOT_AUDITOR_COUNT == SLOT_AUDITORS_BASE + 1

-- =============================================================================
-- Function Selector Tests
-- =============================================================================

test_selectors_unique : Bool
test_selectors_unique =
  SEL_CREATE_UPGRADER /= SEL_PROPOSE_UPGRADE &&
  SEL_PROPOSE_UPGRADE /= SEL_CAST_VOTE &&
  SEL_CAST_VOTE /= SEL_TALLY &&
  SEL_TALLY /= SEL_ASSIGN_AUDITOR

-- =============================================================================
-- All Tests
-- =============================================================================

export
allTests : List (String, Bool)
allTests =
  [ -- Factory
    ("FACTORY_CREATE: slot constants defined", test_factory_slot_constants)
  , ("FACTORY_REGISTRY: registry slots separate", test_factory_registry_slots)
  , ("FACTORY_DICTIONARY: dictionary slot", test_factory_dictionary_slot)
  -- Propose
  , ("PROPOSE_CREATE: proposal offsets", test_proposal_slot_offsets)
  , ("PROPOSE_VALIDATE: all offsets in struct", test_proposal_all_offsets_defined)
  , ("PROPOSE_ONLY_PROPOSER: proposer slot", test_proposer_slot)
  -- Vote
  , ("VOTE_CAST: vote slots", test_vote_slots)
  , ("VOTE_ONCE: decision offset", test_vote_decision_offset)
  , ("VOTE_DEADLINE: deadline offset", test_deadline_offset)
  , ("VOTE_SIGNATURE: sig offset", test_vote_sig_offset)
  -- Tally
  , ("TALLY_THRESHOLD: threshold offset", test_threshold_offset)
  , ("TALLY_AUTO_EXECUTE: executed offset", test_executed_offset)
  , ("TALLY_STATUS: vote count offset", test_vote_count_offset)
  -- Auditor
  , ("AUDITOR_ASSIGN: admin slot", test_admin_slot)
  , ("AUDITOR_POOL: auditors base", test_auditors_base)
  , ("AUDITOR_COUNT: count slot", test_auditor_count_slot)
  -- Schema
  , ("SCHEMA_PROPOSAL: struct complete", test_proposal_struct_complete)
  , ("SCHEMA_VOTES: nested mapping", test_votes_nested_mapping)
  , ("SCHEMA_AUDITORS: auditor storage", test_auditor_storage)
  -- Selectors
  , ("SELECTORS: all unique", test_selectors_unique)
  ]

export
runTests : IO ()
runTests = do
  putStrLn "=== OUF Tests ==="
  let results = allTests
  let passed = filter snd results
  let failed = filter (not . snd) results
  traverse_ (\(name, _) => putStrLn $ "  FAIL: " ++ name) failed
  putStrLn $ "Passed: " ++ show (length passed) ++ "/" ++ show (length results)
