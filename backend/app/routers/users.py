from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.models.users import User

router = APIRouter()


class UserCreate(BaseModel):
    full_name: str
    username: str
    password: str
    role: str


class UserResponse(BaseModel):
    user_id: int
    full_name: str
    username: str
    role: str
    active_status: bool

    class Config:
        from_attributes = True


@router.get("/", response_model=list[UserResponse])
def list_users(db: Session = Depends(get_db)):
    return db.query(User).all()


@router.post("/", response_model=UserResponse, status_code=201)
def create_user(data: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.username == data.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    user = User(**data.model_dump())
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
