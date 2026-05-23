from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.categories import CategoryCreate, CategoryUpdate, CategoryResponse
from app.repositories.category_repo import CategoryRepository
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.get("/", response_model=list[CategoryResponse])
def list_categories(db: Session = Depends(get_db)):
    repo = CategoryRepository(db)
    return repo.get_all()


@router.get("/{category_id}", response_model=CategoryResponse)
def get_category(category_id: int, db: Session = Depends(get_db)):
    repo = CategoryRepository(db)
    category = repo.get_by_id(category_id)
    if not category:
        raise NotFoundError("Category not found")
    return category


@router.post("/", response_model=CategoryResponse, status_code=201)
def create_category(data: CategoryCreate, db: Session = Depends(get_db)):
    repo = CategoryRepository(db)
    category = repo.create(**data.model_dump())
    db.commit()
    db.refresh(category)
    return category


@router.put("/{category_id}", response_model=CategoryResponse)
def update_category(category_id: int, data: CategoryUpdate, db: Session = Depends(get_db)):
    repo = CategoryRepository(db)
    category = repo.get_by_id(category_id)
    if not category:
        raise NotFoundError("Category not found")
    category = repo.update(category, **data.model_dump(exclude_unset=True))
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}")
def delete_category(category_id: int, db: Session = Depends(get_db)):
    repo = CategoryRepository(db)
    category = repo.get_by_id(category_id)
    if not category:
        raise NotFoundError("Category not found")
    repo.delete(category)
    db.commit()
    return {"detail": "Category deleted"}
