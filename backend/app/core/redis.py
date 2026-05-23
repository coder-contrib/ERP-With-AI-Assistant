import redis
import json
from decimal import Decimal
from datetime import timedelta
from app.config import settings


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super().default(obj)


class RedisClient:
    def __init__(self):
        self._client = redis.from_url(settings.redis_url, decode_responses=True)

    @property
    def client(self):
        return self._client

    def get(self, key: str) -> str | None:
        return self._client.get(key)

    def set(self, key: str, value: str, ttl: int | None = None):
        if ttl:
            self._client.setex(key, ttl, value)
        else:
            self._client.set(key, value)

    def delete(self, key: str):
        self._client.delete(key)

    def get_json(self, key: str) -> dict | list | None:
        data = self._client.get(key)
        if data:
            return json.loads(data)
        return None

    def set_json(self, key: str, value: dict | list, ttl: int | None = None):
        data = json.dumps(value, cls=DecimalEncoder)
        self.set(key, data, ttl)

    def delete_pattern(self, pattern: str):
        keys = self._client.keys(pattern)
        if keys:
            self._client.delete(*keys)

    def incr(self, key: str) -> int:
        return self._client.incr(key)

    def expire(self, key: str, ttl: int):
        self._client.expire(key, ttl)

    def ping(self) -> bool:
        try:
            return self._client.ping()
        except redis.ConnectionError:
            return False


redis_client = RedisClient()


def get_redis() -> RedisClient:
    return redis_client
