from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from app.database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True)
    full_name = Column(String(200), nullable=False)
    username = Column(String(100), nullable=False, unique=True)
    password = Column(String(255), nullable=False)
    role = Column(String(30), nullable=False)
    active_status = Column(Boolean, nullable=False, default=True)
    last_login = Column(DateTime)


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    log_id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=False)
    action_type = Column(String(100), nullable=False)
    table_name = Column(String(100))
    record_id = Column(Integer)
    action_date = Column(DateTime, server_default=func.now())
