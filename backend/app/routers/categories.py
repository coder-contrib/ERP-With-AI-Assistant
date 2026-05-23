from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.categories import CategoryCreate, CategoryUpdate, CategoryResponse
from app.services.category_service import CategoryService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[CategoryResponse])
def list_categories(current_user: User = Depends(require_permission("categories:read")), db: Session = Depends(get_db)):
    service = CategoryService(db)
    return service.list_all()


@router.get("/{category_id}", response_model=CategoryResponse)
def get_category(category_id: int, current_user: User = Depends(require_permission("categories:read")), db: Session = Depends(get_db)):
    service = CategoryService(db)
    return service.get(category_id)


@router.post("/", response_model=CategoryResponse, status_code=201)
def create_category(data: CategoryCreate, current_user: User = Depends(require_permission("categories:write")), db: Session = Depends(get_db)):
    service = CategoryService(db)
    return service.create(data)


@router.put("/{category_id}", response_model=CategoryResponse)
def update_category(category_id: int, data: CategoryUpdate, current_user: User = Depends(require_permission("categories:write")), db: Session = Depends(get_db)):
    service = CategoryService(db)
    return service.update(category_id, data)


@router.delete("/{category_id}")
def delete_category(category_id: int, current_user: User = Depends(require_permission("categories:delete")), db: Session = Depends(get_db)):
    service = CategoryService(db)
    return service.delete(category_id)
