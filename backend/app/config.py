from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:password@localhost:5432/ceramic_erp"
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/1"
    secret_key: str = "change-me"
    access_token_expire_minutes: int = 480
    debug: bool = False
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    class Config:
        env_file = ".env"


settings = Settings()
