from app.events.event_bus import get_event_bus
from app.events.sale_events import SALE_CREATED, SALE_RETURNED
from app.events.purchase_events import PURCHASE_CREATED, PURCHASE_RETURNED
from app.events.payment_events import PAYMENT_RECEIVED, PAYMENT_MADE, EXPENSE_CREATED
from app.events.inventory_events import INVENTORY_TRANSFER
from app.events.handlers.analytics_handler import handle_analytics
from app.events.handlers.ai_handler import handle_ai_event
from app.events.handlers.realtime_handler import (
    handle_realtime_sale,
    handle_realtime_inventory,
    handle_realtime_notification,
    handle_realtime_payment,
)


def register_event_handlers():
    """Register all event handlers with the event bus."""
    bus = get_event_bus()

    # Analytics + AI: listen to ALL events
    bus.subscribe_all(handle_analytics)
    bus.subscribe_all(handle_ai_event)

    # Real-time WebSocket handlers
    bus.subscribe(SALE_CREATED, handle_realtime_sale)
    bus.subscribe(PURCHASE_CREATED, handle_realtime_inventory)
    bus.subscribe(PAYMENT_RECEIVED, handle_realtime_payment)
    bus.subscribe(PAYMENT_MADE, handle_realtime_payment)
    bus.subscribe(EXPENSE_CREATED, handle_realtime_notification)

    # All events push to notifications channel
    bus.subscribe_all(handle_realtime_notification)
