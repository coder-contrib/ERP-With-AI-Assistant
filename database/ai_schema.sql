-- ============================================================
-- AI Embeddings Schema (pgvector)
-- Run AFTER main schema.sql
-- Requires: PostgreSQL with pgvector extension
-- ============================================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- AI Embeddings table for RAG and semantic search
CREATE TABLE ai_embeddings (
    embedding_id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1536),
    source_type VARCHAR(50) NOT NULL,
    source_id INTEGER NOT NULL,
    metadata JSONB,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast similarity search (cosine distance)
CREATE INDEX idx_ai_embeddings_vector ON ai_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Index for filtering by source
CREATE INDEX idx_ai_embeddings_source ON ai_embeddings(source_type, source_id);
CREATE INDEX idx_ai_embeddings_date ON ai_embeddings(created_date);

-- AI Conversation History (persistent, beyond Redis TTL)
CREATE TABLE ai_conversations (
    conversation_id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    user_id INTEGER REFERENCES users(user_id),
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'tool', 'system')),
    content TEXT NOT NULL,
    tool_name VARCHAR(100),
    tool_result JSONB,
    tokens_used INTEGER,
    created_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ai_conversations_session ON ai_conversations(session_id);
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);
CREATE INDEX idx_ai_conversations_date ON ai_conversations(created_date);
