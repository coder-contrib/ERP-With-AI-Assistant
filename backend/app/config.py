from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:password@localhost:5432/ceramic_erp"
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/1"
    secret_key: str = "change-me"
    access_token_expire_minutes: int = 480
    anthropic_api_key: str = ""
    ai_model: str = "claude-sonnet-4-20250514"
    openai_api_key: str = ""
    deepgram_api_key: str = ""
    elevenlabs_api_key: str = ""
    elevenlabs_voice_id: str = "21m00Tcm4TlvDq8ikWAM"
    debug: bool = False
    allowed_origins: str = "http://localhost:3000,http://localhost:5173"

    # AI Tool Permissions
    ai_can_write: bool = True
    ai_max_transaction: float = 50000
    ai_can_cancel_invoices: bool = True
    ai_can_refund: bool = True
    ai_max_refund: float = 50000
    ai_can_adjust_stock: bool = True
    ai_can_create_customers: bool = True

    # WhatsApp Integration (Meta Cloud API)
    whatsapp_api_token: str = ""
    whatsapp_phone_number_id: str = ""
    whatsapp_owner_phone: str = ""
    whatsapp_can_send: bool = False
    whatsapp_can_bulk_message: bool = False
    whatsapp_max_messages_per_request: int = 50

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]

    class Config:
        env_file = ".env"


settings = Settings()
