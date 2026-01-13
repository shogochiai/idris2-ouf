||| OUF Schema Version History
|||
||| Defines schema versions and provides compile-time upgrade validation.
||| Any unsafe schema change (field removal, reorder, type change) will
||| fail compilation with a detailed error message.
|||
||| Usage:
||| ```idris
||| -- Define V2 schema
||| ProposalSchemaV2 : Schema
||| ProposalSchemaV2 = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE [...]
|||
||| -- Validate at compile time
||| %runElab checkUpgrade ProposalSchemaV1 ProposalSchemaV2
||| ```
module Main.Storages.SchemaVersions

import Subcontract.Core.Schema
import Subcontract.Core.SchemaCheck
import Main.Storages.Schema

%language ElabReflection

-- =============================================================================
-- Version 1: Initial Deployment (Current)
-- =============================================================================

||| Proposal schema V1 - initial deployment
public export
ProposalSchemaV1 : Schema
ProposalSchemaV1 = ProposalSchema

||| Vote schema V1 - initial deployment
public export
VoteSchemaV1 : Schema
VoteSchemaV1 = VoteSchema

||| Auditor schema V1 - initial deployment
public export
AuditorSchemaV1 : Schema
AuditorSchemaV1 = AuditorSchema

||| Factory schema V1 - initial deployment
public export
FactorySchemaV1 : Schema
FactorySchemaV1 = FactorySchema

||| Factory config schema V1 - initial deployment
public export
FactoryConfigSchemaV1 : Schema
FactoryConfigSchemaV1 = FactoryConfigSchema

-- =============================================================================
-- Version 2: Example Future Upgrade (append-only)
-- =============================================================================

||| Proposal schema V2 - adds execution metadata
|||
||| New fields:
||| - executedAt: Timestamp when upgrade was executed
||| - reasonHash: IPFS hash or keccak256 of upgrade rationale
public export
ProposalSchemaV2 : Schema
ProposalSchemaV2 = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE
  [ Value "target" TAddress
  , Value "newImpl" TAddress
  , Value "selector" TBytes4
  , Value "proposerSig" TBytes32
  , Value "voteCount" TUint256
  , Value "threshold" TUint256
  , Value "deadline" TUint256
  , Value "executed" TUint256
  -- V2 additions (appended):
  , Value "executedAt" TUint256
  , Value "reasonHash" TBytes32
  ]

||| Vote schema V2 - adds vote timestamp
public export
VoteSchemaV2 : Schema
VoteSchemaV2 = MkSchema "ouf.votes" SLOT_VOTES_BASE
  [ Value "decision" TUint8
  , Value "sig" TBytes32
  -- V2 additions:
  , Value "timestamp" TUint256
  ]

-- =============================================================================
-- Compile-Time Upgrade Validation
-- =============================================================================
-- These declarations validate that V2 schemas are safe upgrades from V1.
-- If any validation fails, the module will not compile.

||| Validate Proposal V1 -> V2 upgrade
upgrade_proposal_v1_v2 : ()
upgrade_proposal_v1_v2 = %runElab checkUpgrade ProposalSchemaV1 ProposalSchemaV2

||| Validate Vote V1 -> V2 upgrade
upgrade_vote_v1_v2 : ()
upgrade_vote_v1_v2 = %runElab checkUpgrade VoteSchemaV1 VoteSchemaV2

-- =============================================================================
-- Example: Unsafe Upgrades (uncomment to see compile errors)
-- =============================================================================

-- ||| BAD: Field reordered
-- ProposalSchemaBAD_Reorder : Schema
-- ProposalSchemaBAD_Reorder = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE
--   [ Value "newImpl" TAddress      -- WRONG: was at offset 1, now at 0
--   , Value "target" TAddress       -- WRONG: was at offset 0, now at 1
--   , Value "selector" TBytes4
--   , Value "proposerSig" TBytes32
--   , Value "voteCount" TUint256
--   , Value "threshold" TUint256
--   , Value "deadline" TUint256
--   , Value "executed" TUint256
--   ]
--
-- test_bad_reorder : ()
-- test_bad_reorder = %runElab checkUpgrade ProposalSchemaV1 ProposalSchemaBAD_Reorder
-- ERROR: FIELD_REORDERED - Expected 'target' but found 'newImpl'

-- ||| BAD: Field removed
-- ProposalSchemaBAD_Removed : Schema
-- ProposalSchemaBAD_Removed = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE
--   [ Value "target" TAddress
--   , Value "newImpl" TAddress
--   , Value "selector" TBytes4
--   -- proposerSig REMOVED!
--   , Value "voteCount" TUint256
--   , Value "threshold" TUint256
--   , Value "deadline" TUint256
--   , Value "executed" TUint256
--   ]
--
-- test_bad_removed : ()
-- test_bad_removed = %runElab checkUpgrade ProposalSchemaV1 ProposalSchemaBAD_Removed
-- ERROR: FIELD_REORDERED - Expected 'proposerSig' but found 'voteCount'

-- ||| BAD: Type changed
-- ProposalSchemaBAD_Type : Schema
-- ProposalSchemaBAD_Type = MkSchema "ouf.proposals" SLOT_PROPOSALS_BASE
--   [ Value "target" TUint256       -- WRONG: was TAddress
--   , Value "newImpl" TAddress
--   , Value "selector" TBytes4
--   , Value "proposerSig" TBytes32
--   , Value "voteCount" TUint256
--   , Value "threshold" TUint256
--   , Value "deadline" TUint256
--   , Value "executed" TUint256
--   ]
--
-- test_bad_type : ()
-- test_bad_type = %runElab checkUpgrade ProposalSchemaV1 ProposalSchemaBAD_Type
-- ERROR: TYPE_CHANGED - Type changed from address to uint256
