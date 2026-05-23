"""Seed script to create initial admin user.

Run: python -m app.seeds.create_admin
"""
from app.database import SessionLocal
from app.models.users import User
from app.core.security import hash_password


def create_admin():
    db = SessionLocal()
    try:
        existing = db.query(User).filter(User.username == "admin").first()
        if existing:
            print("Admin user already exists.")
            return

        admin = User(
            full_name="System Administrator",
            username="admin",
            password=hash_password("admin123"),
            role="admin",
        )
        db.add(admin)
        db.commit()
        print("Admin user created successfully.")
        print("Username: admin")
        print("Password: admin123")
        print("IMPORTANT: Change the password after first login!")
    finally:
        db.close()


if __name__ == "__main__":
    create_admin()
