from pydantic import BaseModel


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
