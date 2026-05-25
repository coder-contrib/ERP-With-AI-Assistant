from dataclasses import dataclass, field
from typing import Callable, Any
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@dataclass
class Event:
    event_type: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
    data: dict = field(default_factory=dict)


class EventBus:
    def __init__(self):
        self._handlers: dict[str, list[Callable]] = {}
        self._global_handlers: list[Callable] = []

    def subscribe(self, event_type: str, handler: Callable):
        if event_type not in self._handlers:
            self._handlers[event_type] = []
        self._handlers[event_type].append(handler)

    def subscribe_all(self, handler: Callable):
        self._global_handlers.append(handler)

    def publish(self, event: Event):
        handlers = self._handlers.get(event.event_type, [])
        for handler in handlers:
            try:
                handler(event)
            except Exception as e:
                logger.error(f"Event handler failed for {event.event_type}: {e}")

        for handler in self._global_handlers:
            try:
                handler(event)
            except Exception as e:
                logger.error(f"Global event handler failed for {event.event_type}: {e}")


event_bus = EventBus()


def get_event_bus() -> EventBus:
    return event_bus
