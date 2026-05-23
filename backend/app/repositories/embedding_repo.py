from sqlalchemy.orm import Session
from sqlalchemy import text
from app.models.ai import AIEmbedding, AIConversation


class EmbeddingRepository:
    def __init__(self, db: Session):
        self.db = db

    def store_embedding(self, content: str, embedding: list[float],
                        source_type: str, source_id: int, metadata: dict | None = None) -> int:
        result = self.db.execute(
            text("""
                INSERT INTO ai_embeddings (content, embedding, source_type, source_id, metadata)
                VALUES (:content, :embedding, :source_type, :source_id, :metadata)
                RETURNING embedding_id
            """),
            {
                "content": content,
                "embedding": str(embedding),
                "source_type": source_type,
                "source_id": source_id,
                "metadata": str(metadata) if metadata else None,
            },
        )
        self.db.flush()
        return result.scalar()

    def search_similar(self, query_embedding: list[float], limit: int = 5,
                       source_type: str | None = None) -> list[dict]:
        filter_clause = ""
        params = {"embedding": str(query_embedding), "limit": limit}
        if source_type:
            filter_clause = "AND source_type = :source_type"
            params["source_type"] = source_type

        results = self.db.execute(
            text(f"""
                SELECT embedding_id, content, source_type, source_id, metadata,
                       1 - (embedding <=> :embedding::vector) AS similarity
                FROM ai_embeddings
                WHERE embedding IS NOT NULL {filter_clause}
                ORDER BY embedding <=> :embedding::vector
                LIMIT :limit
            """),
            params,
        ).fetchall()

        return [
            {
                "embedding_id": r.embedding_id,
                "content": r.content,
                "source_type": r.source_type,
                "source_id": r.source_id,
                "metadata": r.metadata,
                "similarity": round(float(r.similarity), 4),
            }
            for r in results
        ]

    def delete_by_source(self, source_type: str, source_id: int):
        self.db.execute(
            text("DELETE FROM ai_embeddings WHERE source_type = :st AND source_id = :sid"),
            {"st": source_type, "sid": source_id},
        )
        self.db.flush()

    def count_by_source(self, source_type: str | None = None) -> int:
        if source_type:
            result = self.db.execute(
                text("SELECT COUNT(*) FROM ai_embeddings WHERE source_type = :st"),
                {"st": source_type},
            )
        else:
            result = self.db.execute(text("SELECT COUNT(*) FROM ai_embeddings"))
        return result.scalar()
