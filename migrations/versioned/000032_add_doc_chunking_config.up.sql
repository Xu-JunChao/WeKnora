-- Migration: 000032_add_doc_chunking_config
-- Description: Add chunking_config column to knowledges for document-level chunking configuration.
-- Document-level chunking config overrides knowledge base config when specified.
DO $$ BEGIN RAISE NOTICE '[Migration 000032] Adding chunking_config column to knowledges'; END $$;

ALTER TABLE knowledges ADD COLUMN IF NOT EXISTS chunking_config JSONB;

COMMENT ON COLUMN knowledges.chunking_config IS 'Document-level chunking configuration (optional, uses knowledge base config when NULL): {"chunkSize": int, "chunkOverlap": int, "separators": [], "enableParentChild": bool, "parentChunkSize": int, "childChunkSize": int}';

DO $$ BEGIN RAISE NOTICE '[Migration 000032] chunking_config column added successfully'; END $$;
