"""Long-term vector memory for the AI assistant.
Stores entity facts, transaction summaries, and contextual information
with embeddings for semantic retrieval (RAG).

Uses OpenAI embeddings + numpy cosine similarity.
No external vector DB needed — stores in Redis for persistence.
"""
import json
import hashlib
import numpy as np
from datetime import datetime
from typing import Optional
import httpx
from app.config import settings
from app.core.redis import get_redis
import logging

logger = logging.getLogger(__name__)

EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIM = 1536
MEMORY_KEY_PREFIX = "ai:vector_memory:"
MEMORY_INDEX_KEY = "ai:vector_memory:index"
MAX_RESULTS = 5


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


class VectorMemory:
    """Semantic memory store for ERP entities and facts.

    Stores memories as:
    - entity_type: customer, product, transaction, fact
    - content: human-readable text
    - embedding: vector representation
    - metadata: structured data (IDs, dates, amounts)
    """

    def __init__(self):
        self.redis = get_redis()

    async def store(self, content: str, entity_type: str, metadata: Optional[dict] = None) -> str:
        """Store a fact/event in vector memory."""
        embedding = await self._get_embedding(content)
        if embedding is None:
            return ""

        memory_id = hashlib.sha256(
            f"{entity_type}:{content}:{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()[:16]

        record = {
            "id": memory_id,
            "content": content,
            "entity_type": entity_type,
            "metadata": metadata or {},
            "embedding": embedding.tolist(),
            "created_at": datetime.utcnow().isoformat(),
        }

        self.redis.set(
            f"{MEMORY_KEY_PREFIX}{memory_id}",
            json.dumps(record, default=str),
            ex=60 * 60 * 24 * 90,  # 90 days TTL
        )
        self.redis.sadd(MEMORY_INDEX_KEY, memory_id)
        return memory_id

    async def search(self, query: str, entity_type: Optional[str] = None, top_k: int = MAX_RESULTS) -> list[dict]:
        """Semantic search over stored memories."""
        query_embedding = await self._get_embedding(query)
        if query_embedding is None:
            return []

        memory_ids = self.redis.smembers(MEMORY_INDEX_KEY)
        if not memory_ids:
            return []

        scored = []
        for mid in memory_ids:
            raw = self.redis.get(f"{MEMORY_KEY_PREFIX}{mid}")
            if not raw:
                continue
            record = json.loads(raw)

            if entity_type and record.get("entity_type") != entity_type:
                continue

            stored_embedding = np.array(record["embedding"])
            score = _cosine_similarity(query_embedding, stored_embedding)
            scored.append((score, record))

        scored.sort(key=lambda x: x[0], reverse=True)
        results = []
        for score, record in scored[:top_k]:
            if score < 0.3:
                break
            results.append({
                "content": record["content"],
                "entity_type": record["entity_type"],
                "metadata": record["metadata"],
                "relevance": round(score, 3),
                "created_at": record["created_at"],
            })
        return results

    def store_transaction_fact(self, customer_id: int, customer_name: str, action: str, details: dict):
        """Store a transaction event for long-term recall (sync wrapper)."""
        import asyncio
        content = f"{customer_name}: {action}. "
        if "total" in details:
            content += f"المبلغ: {details['total']} جنيه. "
        if "items" in details:
            items_str = ", ".join([f"{i.get('name', 'منتج')} x{i.get('quantity', 1)}" for i in details["items"]])
            content += f"الأصناف: {items_str}. "
        content += f"التاريخ: {datetime.utcnow().strftime('%Y-%m-%d')}"

        metadata = {
            "customer_id": customer_id,
            "customer_name": customer_name,
            "action": action,
            **details,
        }

        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.ensure_future(self.store(content, "transaction", metadata))
            else:
                loop.run_until_complete(self.store(content, "transaction", metadata))
        except Exception as e:
            logger.warning(f"Failed to store transaction fact: {e}")

    def store_customer_fact(self, customer_id: int, name: str, fact: str):
        """Store a customer-related fact."""
        import asyncio
        content = f"{name} (عميل #{customer_id}): {fact}"
        metadata = {"customer_id": customer_id, "customer_name": name}
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.ensure_future(self.store(content, "customer", metadata))
            else:
                loop.run_until_complete(self.store(content, "customer", metadata))
        except Exception as e:
            logger.warning(f"Failed to store customer fact: {e}")

    async def get_context_for_query(self, query: str) -> str:
        """Get relevant long-term context for a user query. Returns formatted text."""
        results = await self.search(query, top_k=5)
        if not results:
            return ""

        lines = ["[ذاكرة طويلة المدى - معلومات سابقة ذات صلة]:"]
        for r in results:
            lines.append(f"• {r['content']} (صلة: {r['relevance']})")
        return "\n".join(lines)

    async def _get_embedding(self, text: str) -> Optional[np.ndarray]:
        """Get embedding from OpenAI API."""
        if not settings.openai_api_key:
            return None
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    "https://api.openai.com/v1/embeddings",
                    headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                    json={"model": EMBEDDING_MODEL, "input": text},
                    timeout=10,
                )
                resp.raise_for_status()
                data = resp.json()
                return np.array(data["data"][0]["embedding"])
        except Exception as e:
            logger.warning(f"Embedding API error: {e}")
            return None
