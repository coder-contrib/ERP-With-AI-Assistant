from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    full_name: str
    role: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


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
