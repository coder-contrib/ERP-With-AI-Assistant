from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.database import get_db
from app.models.users import User
from app.core.security import verify_password, hash_password, create_access_token
from app.core.deps import get_current_user
from app.core.redis import get_redis
from app.services.cache_service import CacheService
from app.schemas.users import LoginRequest, TokenResponse, ChangePasswordRequest

router = APIRouter()


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    if not user or not verify_password(data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    if not user.active_status:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    user.last_login = datetime.utcnow()
    db.commit()

    token = create_access_token({"sub": str(user.user_id), "role": user.role})

    cache = CacheService(get_redis())
    cache.set_session(user.user_id, {
        "user_id": user.user_id,
        "username": user.username,
        "role": user.role,
        "full_name": user.full_name,
        "login_time": datetime.utcnow().isoformat(),
    })

    return TokenResponse(
        access_token=token,
        user_id=user.user_id,
        full_name=user.full_name,
        role=user.role,
    )


@router.get("/me", response_model=TokenResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return TokenResponse(
        access_token="",
        user_id=current_user.user_id,
        full_name=current_user.full_name,
        role=current_user.role,
    )


@router.post("/change-password")
def change_password(data: ChangePasswordRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not verify_password(data.current_password, current_user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.password = hash_password(data.new_password)
    db.commit()
    return {"detail": "Password changed successfully"}


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    cache = CacheService(get_redis())
    cache.invalidate_session(current_user.user_id)
    return {"detail": "Logged out successfully"}
