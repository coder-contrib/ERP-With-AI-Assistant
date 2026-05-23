from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:password@localhost:5432/ceramic_erp"
    secret_key: str = "change-me"
    debug: bool = False
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    class Config:
        env_file = ".env"


settings = Settings()
