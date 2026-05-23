from app.events.event_bus import Event
from app.core.redis import get_redis
from app.services.cache_service import CacheService
import logging

logger = logging.getLogger(__name__)


def handle_analytics(event: Event):
    """Invalidate dashboard cache on any financial event."""
    cache = CacheService(get_redis())
    cache.invalidate_dashboard()
    logger.info(f"Analytics: dashboard cache invalidated for event {event.event_type}")
