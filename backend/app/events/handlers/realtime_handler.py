import asyncio
from app.core.websocket import get_ws_manager
from app.events.event_bus import Event
import logging

logger = logging.getLogger(__name__)


def _dispatch_async(coro):
    """Safely dispatch an async coroutine from any context (sync or async)."""
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(coro)
    except RuntimeError:
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(coro, loop)
            else:
                loop.run_until_complete(coro)
        except RuntimeError:
            import threading
            thread = threading.Thread(target=asyncio.run, args=(coro,), daemon=True)
            thread.start()


def handle_realtime_sale(event: Event):
    """Push sale event to dashboard WebSocket channel."""
    _dispatch_async(_broadcast_sale(event))


def handle_realtime_inventory(event: Event):
    """Push inventory update to inventory WebSocket channel."""
    _dispatch_async(_broadcast_inventory(event))


def handle_realtime_notification(event: Event):
    """Push notification to all connected users."""
    _dispatch_async(_broadcast_notification(event))


def handle_realtime_payment(event: Event):
    """Push payment event to dashboard."""
    _dispatch_async(_broadcast_payment(event))


async def _broadcast_sale(event: Event):
    mgr = get_ws_manager()
    await mgr.broadcast("dashboard", {
        "type": "sale_created",
        "data": {
            "invoice_id": event.data.get("invoice_id"),
            "invoice_number": event.data.get("invoice_number"),
            "total_amount": event.data.get("total_amount"),
            "timestamp": event.timestamp.isoformat(),
        },
    })


async def _broadcast_inventory(event: Event):
    mgr = get_ws_manager()
    await mgr.broadcast("inventory", {
        "type": "stock_updated",
        "data": {
            "event_type": event.event_type,
            "timestamp": event.timestamp.isoformat(),
        },
    })


async def _broadcast_notification(event: Event):
    mgr = get_ws_manager()
    await mgr.broadcast("notifications", {
        "type": "new_notification",
        "data": {
            "event_type": event.event_type,
            "summary": _summarize(event),
            "timestamp": event.timestamp.isoformat(),
        },
    })


async def _broadcast_payment(event: Event):
    mgr = get_ws_manager()
    await mgr.broadcast("dashboard", {
        "type": "payment_update",
        "data": {
            "event_type": event.event_type,
            "amount": event.data.get("amount") or event.data.get("paid_amount"),
            "timestamp": event.timestamp.isoformat(),
        },
    })


def _summarize(event: Event) -> str:
    data = event.data
    if event.event_type == "sale.created":
        return f"New sale: #{data.get('invoice_number', '')} - ${data.get('total_amount', '0')}"
    if event.event_type == "purchase.created":
        return f"New purchase: ${data.get('total_amount', '0')}"
    if event.event_type == "payment.received":
        return f"Payment received: ${data.get('amount', '0')}"
    if event.event_type == "payment.made":
        return f"Payment made: ${data.get('amount', '0')}"
    if event.event_type == "expense.created":
        return f"Expense: {data.get('category', '')} - ${data.get('amount', '0')}"
    return event.event_type
