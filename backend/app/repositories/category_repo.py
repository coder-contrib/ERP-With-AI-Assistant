from sqlalchemy.orm import Session
from app.models.categories import Category


class CategoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[Category]:
        return self.db.query(Category).all()

    def get_by_id(self, category_id: int) -> Category | None:
        return self.db.query(Category).filter(Category.category_id == category_id).first()

    def create(self, **kwargs) -> Category:
        category = Category(**kwargs)
        self.db.add(category)
        self.db.flush()
        return category

    def update(self, category: Category, **kwargs) -> Category:
        for key, value in kwargs.items():
            if value is not None:
                setattr(category, key, value)
        self.db.flush()
        return category

    def delete(self, category: Category) -> None:
        self.db.delete(category)
        self.db.flush()
