from app.events.event_bus import get_event_bus
from app.events.sale_events import SALE_CREATED, SALE_RETURNED
from app.events.purchase_events import PURCHASE_CREATED, PURCHASE_RETURNED
from app.events.payment_events import PAYMENT_RECEIVED, PAYMENT_MADE, EXPENSE_CREATED
from app.events.inventory_events import INVENTORY_TRANSFER
from app.events.handlers.analytics_handler import handle_analytics
from app.events.handlers.ai_handler import handle_ai_event


def register_event_handlers():
    """Register all event handlers with the event bus.
    Called once at application startup.
    """
    bus = get_event_bus()

    # Analytics handler listens to ALL events
    bus.subscribe_all(handle_analytics)

    # AI handler listens to ALL events for context building
    bus.subscribe_all(handle_ai_event)
