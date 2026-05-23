"""RAG (Retrieval-Augmented Generation) module.
Uses pgvector for semantic search when embeddings are available,
falls back to keyword search otherwise.
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.products import Product
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.repositories.embedding_repo import EmbeddingRepository


class ERPContextRetriever:
    """Retrieves relevant ERP context for AI queries.
    Uses pgvector semantic search when embeddings exist,
    keyword matching as fallback.
    """

    def __init__(self, db: Session):
        self.db = db
        self.embedding_repo = EmbeddingRepository(db)

    def semantic_search(self, query_embedding: list[float], limit: int = 5,
                        source_type: str | None = None) -> list[dict]:
        return self.embedding_repo.search_similar(query_embedding, limit, source_type)

    def search_products(self, query: str, limit: int = 5) -> list[dict]:
        results = self.db.query(Product).filter(
            Product.product_name.ilike(f"%{query}%"),
            Product.active_status == True,
        ).limit(limit).all()
        return [
            {
                "product_id": p.product_id,
                "product_name": p.product_name,
                "base_unit": p.base_unit,
                "selling_price": str(p.selling_price),
            }
            for p in results
        ]

    def search_customers(self, query: str, limit: int = 5) -> list[dict]:
        results = self.db.query(Customer).filter(
            Customer.customer_name.ilike(f"%{query}%")
        ).limit(limit).all()
        return [
            {
                "customer_id": c.customer_id,
                "customer_name": c.customer_name,
                "balance": str(c.current_balance),
            }
            for c in results
        ]

    def search_suppliers(self, query: str, limit: int = 5) -> list[dict]:
        results = self.db.query(Supplier).filter(
            Supplier.supplier_name.ilike(f"%{query}%")
        ).limit(limit).all()
        return [
            {
                "supplier_id": s.supplier_id,
                "supplier_name": s.supplier_name,
                "balance": str(s.current_balance),
            }
            for s in results
        ]
