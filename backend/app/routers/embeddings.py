from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import require_admin
from app.models.users import User
from app.ai.embeddings.service import EmbeddingService
from app.repositories.embedding_repo import EmbeddingRepository

router = APIRouter()


class EmbeddingStoreRequest(BaseModel):
    content: str
    embedding: list[float]
    source_type: str
    source_id: int
    metadata: dict | None = None


class EmbeddingSearchRequest(BaseModel):
    embedding: list[float]
    limit: int = 5
    source_type: str | None = None


@router.get("/stats")
def embedding_stats(current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    service = EmbeddingService(db)
    return service.get_stats()


@router.post("/store")
def store_embedding(data: EmbeddingStoreRequest, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    repo = EmbeddingRepository(db)
    embedding_id = repo.store_embedding(
        content=data.content,
        embedding=data.embedding,
        source_type=data.source_type,
        source_id=data.source_id,
        metadata=data.metadata,
    )
    db.commit()
    return {"embedding_id": embedding_id}


@router.post("/search")
def search_embeddings(data: EmbeddingSearchRequest, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    repo = EmbeddingRepository(db)
    results = repo.search_similar(
        query_embedding=data.embedding,
        limit=data.limit,
        source_type=data.source_type,
    )
    return {"results": results}


@router.delete("/source/{source_type}/{source_id}")
def delete_embeddings(source_type: str, source_id: int, current_user: User = Depends(require_admin), db: Session = Depends(get_db)):
    repo = EmbeddingRepository(db)
    repo.delete_by_source(source_type, source_id)
    db.commit()
    return {"detail": f"Embeddings deleted for {source_type}/{source_id}"}
