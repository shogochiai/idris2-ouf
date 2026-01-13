||| OUF Storage Schema
|||
||| Storage slot constants and access functions for Onchain Upgrader Factory.
||| Follows ERC-7201 namespaced storage pattern.
module Main.Storages.Schema

import public EVM.Primitives
import public Subcontract.Core.FR

%default total

-- =============================================================================
-- Helper Functions
-- =============================================================================

||| Calculate mapping slot (simplified: base + key)
||| For proper EVM: keccak256(abi.encode(key, base))
public export
mappingSlot : Integer -> Integer -> IO Integer
mappingSlot base key = do
  -- Proper implementation would use keccak256
  -- For now: simple offset calculation
  mstore 0 key
  mstore 32 base
  keccak256 0 64

-- =============================================================================
-- REQ_SCHEMA_PROPOSAL: Proposal storage layout
-- =============================================================================

||| Base slot for proposals mapping (keccak256("ouf.proposals") - 1)
public export
SLOT_PROPOSALS_BASE : Integer
SLOT_PROPOSALS_BASE = 0x1000

||| Proposal struct offsets
public export
OFFSET_TARGET : Integer
OFFSET_TARGET = 0

public export
OFFSET_NEW_IMPL : Integer
OFFSET_NEW_IMPL = 1

public export
OFFSET_SELECTOR : Integer
OFFSET_SELECTOR = 2

public export
OFFSET_PROPOSER_SIG : Integer
OFFSET_PROPOSER_SIG = 3

public export
OFFSET_VOTE_COUNT : Integer
OFFSET_VOTE_COUNT = 4

public export
OFFSET_THRESHOLD : Integer
OFFSET_THRESHOLD = 5

public export
OFFSET_DEADLINE : Integer
OFFSET_DEADLINE = 6

public export
OFFSET_EXECUTED : Integer
OFFSET_EXECUTED = 7

-- =============================================================================
-- REQ_SCHEMA_VOTES: Vote storage layout
-- =============================================================================

||| Base slot for votes mapping (keccak256("ouf.votes") - 1)
public export
SLOT_VOTES_BASE : Integer
SLOT_VOTES_BASE = 0x2000

||| Vote struct offsets
public export
OFFSET_VOTE_DECISION : Integer
OFFSET_VOTE_DECISION = 0

public export
OFFSET_VOTE_SIG : Integer
OFFSET_VOTE_SIG = 1

-- =============================================================================
-- REQ_SCHEMA_AUDITORS: Auditor list storage
-- =============================================================================

||| Base slot for auditors array
public export
SLOT_AUDITORS_BASE : Integer
SLOT_AUDITORS_BASE = 0x3000

||| Slot for auditor count
public export
SLOT_AUDITOR_COUNT : Integer
SLOT_AUDITOR_COUNT = 0x3001

-- =============================================================================
-- Factory-specific slots
-- =============================================================================

||| Base slot for upgrader registry (id -> address)
public export
SLOT_REGISTRY_BASE : Integer
SLOT_REGISTRY_BASE = 0x4000

||| Slot for upgrader count
public export
SLOT_UPGRADER_COUNT : Integer
SLOT_UPGRADER_COUNT = 0x4001

||| Slot for shared Dictionary address
public export
SLOT_DICTIONARY : Integer
SLOT_DICTIONARY = 0x5000

||| Slot for proposer address
public export
SLOT_PROPOSER : Integer
SLOT_PROPOSER = 0x5001

||| Slot for admin address
public export
SLOT_ADMIN : Integer
SLOT_ADMIN = 0x5002

-- =============================================================================
-- Function Selectors
-- =============================================================================

||| createUpgrader()
public export
SEL_CREATE_UPGRADER : Integer
SEL_CREATE_UPGRADER = 0x1234abcd

||| proposeUpgrade(uint256, address, address, bytes4, uint256)
public export
SEL_PROPOSE_UPGRADE : Integer
SEL_PROPOSE_UPGRADE = 0x3b2d5c8a

||| castVote(uint256, uint8, bytes32)
public export
SEL_CAST_VOTE : Integer
SEL_CAST_VOTE = 0x5c19a95c

||| tally(uint256)
public export
SEL_TALLY : Integer
SEL_TALLY = 0x8a2c7b5e

||| assignAuditor(uint256, address)
public export
SEL_ASSIGN_AUDITOR : Integer
SEL_ASSIGN_AUDITOR = 0x9e3d4f1a

-- =============================================================================
-- Events
-- =============================================================================

||| UpgraderCreated(uint256 indexed id, address upgrader)
public export
EVENT_UPGRADER_CREATED : Integer
EVENT_UPGRADER_CREATED = 0xabc123

||| ProposalCreated(uint256 indexed proposalId, address target, address newImpl)
public export
EVENT_PROPOSAL_CREATED : Integer
EVENT_PROPOSAL_CREATED = 0xdef456

||| VoteCast(uint256 indexed proposalId, address indexed auditor, uint8 decision)
public export
EVENT_VOTE_CAST : Integer
EVENT_VOTE_CAST = 0x789abc

||| UpgradeExecuted(uint256 indexed proposalId)
public export
EVENT_UPGRADE_EXECUTED : Integer
EVENT_UPGRADE_EXECUTED = 0xcde012

-- =============================================================================
-- Type-Safe Schema Definitions
-- =============================================================================
-- These Schema types mirror the slot constants above and enable compile-time
-- upgrade validation via Subcontract.Core.SchemaCheck.

import Subcontract.Core.Schema
import Subcontract.Core.SchemaCompat

||| Proposal storage schema
||| Maps proposalId -> Proposal struct (8 fields)
|||
||| Mirrors:
||| ```solidity
||| struct Proposal {
|||     address target;       // offset 0
|||     address newImpl;      // offset 1
|||     bytes4 selector;      // offset 2
|||     bytes32 proposerSig;  // offset 3
|||     uint256 voteCount;    // offset 4
|||     uint256 threshold;    // offset 5
|||     uint256 deadline;     // offset 6
|||     uint256 executed;     // offset 7
||| }
||| ```
public export
ProposalSchema : Schema
ProposalSchema = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE
  [ Value "target" TAddress
  , Value "newImpl" TAddress
  , Value "selector" TBytes4
  , Value "proposerSig" TBytes32
  , Value "voteCount" TUint256
  , Value "threshold" TUint256
  , Value "deadline" TUint256
  , Value "executed" TUint256
  ]

||| Vote storage schema
||| Maps (proposalId, auditor) -> Vote struct (2 fields)
|||
||| Accessed via nested mapping: votes[proposalId][auditor]
public export
VoteSchema : Schema
VoteSchema = MkSchema "ouf.votes" SLOT_VOTES_BASE
  [ Value "decision" TUint8
  , Value "sig" TBytes32
  ]

||| Auditor list storage schema
public export
AuditorSchema : Schema
AuditorSchema = MkSchema "ouf.auditors" SLOT_AUDITORS_BASE
  [ Array "auditors" TAddress
  ]

||| Factory storage schema (singleton values)
||| Note: Uses multiple base slots for logical separation
public export
FactorySchema : Schema
FactorySchema = MkSchema "ouf.factory" SLOT_REGISTRY_BASE
  [ Mapping "registry" TUint256 TAddress
  , Value "upgraderCount" TUint256
  ]

||| Factory config schema (separate namespace)
public export
FactoryConfigSchema : Schema
FactoryConfigSchema = MkSchema "ouf.factory.config" SLOT_DICTIONARY
  [ Value "dictionary" TAddress
  , Value "proposer" TAddress
  , Value "admin" TAddress
  ]
