from app.core.redis import RedisClient

STOCK_KEY = "stock:{product_id}:{warehouse_id}"
STOCK_ALL_KEY = "stock:all"
STOCK_TTL = 300  # 5 minutes

DASHBOARD_KEY = "dashboard:stats"
DASHBOARD_TTL = 60  # 1 minute

SESSION_KEY = "session:{user_id}"
SESSION_TTL = 28800  # 8 hours

AI_CONVERSATION_KEY = "ai:conversation:{session_id}"
AI_CONVERSATION_TTL = 3600  # 1 hour


class CacheService:
    def __init__(self, redis: RedisClient):
        self.redis = redis

    # --- STOCK CACHE ---

    def get_stock(self, product_id: int, warehouse_id: int) -> dict | None:
        key = STOCK_KEY.format(product_id=product_id, warehouse_id=warehouse_id)
        return self.redis.get_json(key)

    def set_stock(self, product_id: int, warehouse_id: int, data: dict):
        key = STOCK_KEY.format(product_id=product_id, warehouse_id=warehouse_id)
        self.redis.set_json(key, data, STOCK_TTL)

    def invalidate_stock(self, product_id: int, warehouse_id: int):
        key = STOCK_KEY.format(product_id=product_id, warehouse_id=warehouse_id)
        self.redis.delete(key)
        self.redis.delete(STOCK_ALL_KEY)

    def get_all_stock(self) -> list | None:
        return self.redis.get_json(STOCK_ALL_KEY)

    def set_all_stock(self, data: list):
        self.redis.set_json(STOCK_ALL_KEY, data, STOCK_TTL)

    def invalidate_all_stock(self):
        self.redis.delete_pattern("stock:*")

    # --- DASHBOARD CACHE ---

    def get_dashboard(self) -> dict | None:
        return self.redis.get_json(DASHBOARD_KEY)

    def set_dashboard(self, data: dict):
        self.redis.set_json(DASHBOARD_KEY, data, DASHBOARD_TTL)

    def invalidate_dashboard(self):
        self.redis.delete(DASHBOARD_KEY)

    # --- SESSION CACHE ---

    def get_session(self, user_id: int) -> dict | None:
        key = SESSION_KEY.format(user_id=user_id)
        return self.redis.get_json(key)

    def set_session(self, user_id: int, data: dict):
        key = SESSION_KEY.format(user_id=user_id)
        self.redis.set_json(key, data, SESSION_TTL)

    def invalidate_session(self, user_id: int):
        key = SESSION_KEY.format(user_id=user_id)
        self.redis.delete(key)

    # --- AI CONVERSATION MEMORY ---

    def get_ai_conversation(self, session_id: str) -> list | None:
        key = AI_CONVERSATION_KEY.format(session_id=session_id)
        return self.redis.get_json(key)

    def set_ai_conversation(self, session_id: str, messages: list):
        key = AI_CONVERSATION_KEY.format(session_id=session_id)
        self.redis.set_json(key, messages, AI_CONVERSATION_TTL)

    def append_ai_message(self, session_id: str, message: dict):
        messages = self.get_ai_conversation(session_id) or []
        messages.append(message)
        self.set_ai_conversation(session_id, messages)

    def clear_ai_conversation(self, session_id: str):
        key = AI_CONVERSATION_KEY.format(session_id=session_id)
        self.redis.delete(key)
