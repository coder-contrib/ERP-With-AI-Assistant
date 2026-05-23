from sqlalchemy import Column, Integer, String, Text, DateTime, JSON
from sqlalchemy.sql import func
from app.database import Base


class AIEmbedding(Base):
    __tablename__ = "ai_embeddings"

    embedding_id = Column(Integer, primary_key=True)
    content = Column(Text, nullable=False)
    # embedding column handled via raw SQL (pgvector type)
    source_type = Column(String(50), nullable=False)
    source_id = Column(Integer, nullable=False)
    metadata_ = Column("metadata", JSON)
    created_date = Column(DateTime, server_default=func.now())


class AIConversation(Base):
    __tablename__ = "ai_conversations"

    conversation_id = Column(Integer, primary_key=True)
    session_id = Column(String(100), nullable=False)
    user_id = Column(Integer)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    tool_name = Column(String(100))
    tool_result = Column(JSON)
    tokens_used = Column(Integer)
    created_date = Column(DateTime, server_default=func.now())
