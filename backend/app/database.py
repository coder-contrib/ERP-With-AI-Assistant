from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase, Session
from contextlib import contextmanager
from app.config import settings

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def transaction(db: Session):
    """Context manager for atomic transactions.
    Usage:
        with transaction(db):
            # all operations here are atomic
            # auto-commits on success, auto-rollbacks on exception
    """
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
