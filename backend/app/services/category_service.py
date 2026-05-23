from sqlalchemy.orm import Session
from app.database import transaction
from app.repositories.category_repo import CategoryRepository
from app.schemas.categories import CategoryCreate, CategoryUpdate
from app.models.categories import Category
from app.core.exceptions import NotFoundError


class CategoryService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CategoryRepository(db)

    def list_all(self) -> list[Category]:
        return self.repo.get_all()

    def get(self, category_id: int) -> Category:
        category = self.repo.get_by_id(category_id)
        if not category:
            raise NotFoundError("Category not found")
        return category

    def create(self, data: CategoryCreate) -> Category:
        with transaction(self.db):
            category = self.repo.create(**data.model_dump())
        self.db.refresh(category)
        return category

    def update(self, category_id: int, data: CategoryUpdate) -> Category:
        with transaction(self.db):
            category = self.get(category_id)
            category = self.repo.update(category, **data.model_dump(exclude_unset=True))
        self.db.refresh(category)
        return category

    def delete(self, category_id: int) -> dict:
        with transaction(self.db):
            category = self.get(category_id)
            self.repo.delete(category)
        return {"detail": "Category deleted"}
