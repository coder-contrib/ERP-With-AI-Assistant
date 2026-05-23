from app.events.event_bus import Event
from app.core.redis import get_redis
from app.services.cache_service import CacheService
import logging

logger = logging.getLogger(__name__)


def handle_ai_event(event: Event):
    """Store events for AI context building.
    The AI assistant can use these events to understand
    what happened in the system and provide insights.
    """
    cache = CacheService(get_redis())
    cache.append_ai_message("system_events", {
        "event_type": event.event_type,
        "timestamp": event.timestamp.isoformat(),
        "summary": _summarize_event(event),
    })


def _summarize_event(event: Event) -> str:
    data = event.data
    if event.event_type == "sale.created":
        return f"Sale #{data.get('invoice_number', '')} for {data.get('total_amount', 0)}"
    if event.event_type == "purchase.created":
        return f"Purchase for {data.get('total_amount', 0)}"
    if event.event_type == "payment.received":
        return f"Payment received: {data.get('amount', 0)}"
    if event.event_type == "payment.made":
        return f"Payment made: {data.get('amount', 0)}"
    if event.event_type == "expense.created":
        return f"Expense ({data.get('category', '')}): {data.get('amount', 0)}"
    return f"{event.event_type}"
