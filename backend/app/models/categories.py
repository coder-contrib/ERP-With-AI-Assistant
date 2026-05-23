from sqlalchemy import Column, Integer, String, Text
from app.database import Base


class Category(Base):
    __tablename__ = "categories"

    category_id = Column(Integer, primary_key=True)
    category_name = Column(String(100), nullable=False)
    description = Column(Text)
