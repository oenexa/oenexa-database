-- ==============================================================================
-- OENEXA AI & Autonomous Agent Swarm Schema (oenexa_ai_db)
-- Multi-Agent Swarms, Tasks, Short/Long-Term Memory & RAG Vector Store
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Enums
CREATE TYPE agent_role_enum AS ENUM ('COORDINATOR', 'RESEARCHER', 'CODER', 'SECURITY_AUDITOR', 'TRADER', 'ORCHESTRATOR');
CREATE TYPE task_status_enum AS ENUM ('QUEUED', 'IN_PROGRESS', 'WAITING_INPUT', 'COMPLETED', 'FAILED', 'TERMINATED');

-- 1. Autonomous Agent Registry
CREATE TABLE IF NOT EXISTS ai_agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    role agent_role_enum NOT NULL DEFAULT 'RESEARCHER',
    model_identifier VARCHAR(100) NOT NULL, -- e.g. gemini-2.5-pro, claude-3-7-sonnet
    system_prompt TEXT NOT NULL,
    temperature NUMERIC(3, 2) NOT NULL DEFAULT 0.70,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Swarm Sessions (Multi-Agent Workspaces)
CREATE TABLE IF NOT EXISTS swarm_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    initiator_user_id UUID,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ
);

-- 3. Execution Tasks
CREATE TABLE IF NOT EXISTS swarm_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES swarm_sessions(id) ON DELETE CASCADE,
    assigned_agent_id UUID REFERENCES ai_agents(id),
    task_goal TEXT NOT NULL,
    status task_status_enum NOT NULL DEFAULT 'QUEUED',
    parent_task_id UUID REFERENCES swarm_tasks(id),
    input_payload JSONB,
    output_result JSONB,
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- 4. Agent Memory & Message Board
CREATE TABLE IF NOT EXISTS agent_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES swarm_sessions(id) ON DELETE CASCADE,
    sender_agent_id UUID REFERENCES ai_agents(id),
    recipient_agent_id UUID REFERENCES ai_agents(id),
    message_type VARCHAR(32) NOT NULL DEFAULT 'MESSAGE', -- BROADCAST, DIRECT, TOOL_CALL
    content TEXT NOT NULL,
    tool_name VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. RAG Vector Knowledge Base (pgvector 1536-dimensional embeddings)
CREATE TABLE IF NOT EXISTS rag_document_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_name VARCHAR(100) NOT NULL DEFAULT 'global_knowledge',
    document_uri TEXT NOT NULL,
    chunk_index INT NOT NULL,
    chunk_text TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_session ON swarm_tasks(session_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_agent ON swarm_tasks(assigned_agent_id);
CREATE INDEX IF NOT EXISTS idx_messages_session ON agent_messages(session_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_rag_collection ON rag_document_chunks(collection_name);
-- HNSW Vector Index for Sub-Millisecond Cosine Similarity Search
CREATE INDEX IF NOT EXISTS idx_rag_embedding_hnsw 
ON rag_document_chunks USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
