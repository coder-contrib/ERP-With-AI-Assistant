from sqlalchemy.orm import Session
from sqlalchemy import text
from app.repositories.embedding_repo import EmbeddingRepository
from app.models.products import Product
from app.models.customers import Customer
from app.models.categories import Category


class EmbeddingService:
    """Manages vector embeddings for semantic search.
    Stores product/customer/category data as embeddings for AI RAG.
    """

    def __init__(self, db: Session):
        self.db = db
        self.repo = EmbeddingRepository(db)

    def search(self, query_embedding: list[float], limit: int = 5,
               source_type: str | None = None) -> list[dict]:
        return self.repo.search_similar(query_embedding, limit, source_type)

    def embed_product(self, product_id: int, embedding: list[float]):
        product = self.db.query(Product).filter(Product.product_id == product_id).first()
        if not product:
            return
        content = f"{product.product_name} | Base unit: {product.base_unit} | Price: {product.selling_price}"
        self.repo.delete_by_source("product", product_id)
        self.repo.store_embedding(
            content=content,
            embedding=embedding,
            source_type="product",
            source_id=product_id,
            metadata={"name": product.product_name, "barcode": product.barcode},
        )
        self.db.commit()

    def embed_customer(self, customer_id: int, embedding: list[float]):
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            return
        content = f"{customer.customer_name} | Phone: {customer.phone_number or 'N/A'} | Balance: {customer.current_balance}"
        self.repo.delete_by_source("customer", customer_id)
        self.repo.store_embedding(
            content=content,
            embedding=embedding,
            source_type="customer",
            source_id=customer_id,
            metadata={"name": customer.customer_name},
        )
        self.db.commit()

    def embed_all_products(self, embedding_fn):
        """Batch embed all products. embedding_fn(text) -> list[float]"""
        products = self.db.query(Product).filter(Product.active_status == True).all()
        count = 0
        for product in products:
            content = f"{product.product_name} | Base unit: {product.base_unit} | Price: {product.selling_price}"
            embedding = embedding_fn(content)
            if embedding:
                self.repo.delete_by_source("product", product.product_id)
                self.repo.store_embedding(
                    content=content,
                    embedding=embedding,
                    source_type="product",
                    source_id=product.product_id,
                    metadata={"name": product.product_name},
                )
                count += 1
        self.db.commit()
        return count

    def embed_all_customers(self, embedding_fn):
        """Batch embed all customers. embedding_fn(text) -> list[float]"""
        customers = self.db.query(Customer).all()
        count = 0
        for customer in customers:
            content = f"{customer.customer_name} | Phone: {customer.phone_number or 'N/A'}"
            embedding = embedding_fn(content)
            if embedding:
                self.repo.delete_by_source("customer", customer.customer_id)
                self.repo.store_embedding(
                    content=content,
                    embedding=embedding,
                    source_type="customer",
                    source_id=customer.customer_id,
                    metadata={"name": customer.customer_name},
                )
                count += 1
        self.db.commit()
        return count

    def get_stats(self) -> dict:
        return {
            "total": self.repo.count_by_source(),
            "products": self.repo.count_by_source("product"),
            "customers": self.repo.count_by_source("customer"),
            "categories": self.repo.count_by_source("category"),
        }
