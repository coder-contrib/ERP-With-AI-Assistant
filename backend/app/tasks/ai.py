from app.celery_app import celery_app
from app.database import SessionLocal
from app.core.redis import get_redis
from app.services.cache_service import CacheService


@celery_app.task(name="app.tasks.ai.process_ai_query")
def process_ai_query(session_id: str, query: str, context: dict | None = None):
    """Placeholder for AI query processing.
    Will be implemented when AI service is integrated.
    """
    cache = CacheService(get_redis())
    cache.append_ai_message(session_id, {"role": "user", "content": query})
    response = f"AI processing placeholder for: {query}"
    cache.append_ai_message(session_id, {"role": "assistant", "content": response})
    return {"status": "success", "session_id": session_id, "response": response}


@celery_app.task(name="app.tasks.ai.train_embeddings")
def train_embeddings():
    """Placeholder for AI embeddings training.
    Will process product data, invoices, etc. for semantic search.
    """
    return {"status": "success", "detail": "Embeddings training placeholder"}
