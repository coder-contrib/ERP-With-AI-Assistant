from pydantic import BaseModel
from decimal import Decimal


class CategoryCreate(BaseModel):
    category_name: str
    description: str | None = None


class CategoryUpdate(BaseModel):
    category_name: str | None = None
    description: str | None = None


class CategoryResponse(BaseModel):
    category_id: int
    category_name: str
    description: str | None

    class Config:
        from_attributes = True
