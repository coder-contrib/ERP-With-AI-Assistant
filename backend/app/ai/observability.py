"""Observability Layer for AI decisions.

Logs every AI decision with:
- Tool chosen and why (from Claude's reasoning)
- Input parameters
- Output result
- Execution time
- Session context
- User role

Stores in both structured logs (for debugging) and Redis (for audit dashboard).
"""
import json
import time
import uuid
from datetime import datetime
from typing import Optional
from app.core.redis import get_redis
import logging

logger = logging.getLogger(__name__)

AUDIT_KEY_PREFIX = "ai:audit:"
AUDIT_INDEX_KEY = "ai:audit:index"
AUDIT_SESSION_PREFIX = "ai:audit:session:"
MAX_AUDIT_ENTRIES = 1000


class AIAuditEntry:
    """Single auditable AI action."""

    def __init__(
        self,
        session_id: str,
        user_role: str,
        tool_name: str,
        tool_input: dict,
        decision_reason: Optional[str] = None,
    ):
        self.entry_id = str(uuid.uuid4())[:12]
        self.session_id = session_id
        self.user_role = user_role
        self.tool_name = tool_name
        self.tool_input = tool_input
        self.decision_reason = decision_reason
        self.started_at = time.time()
        self.finished_at: Optional[float] = None
        self.result: Optional[dict] = None
        self.error: Optional[str] = None
        self.was_blocked = False
        self.blocked_reason: Optional[str] = None

    def complete(self, result: dict):
        self.finished_at = time.time()
        self.result = result

    def fail(self, error: str):
        self.finished_at = time.time()
        self.error = error

    def block(self, reason: str):
        self.finished_at = time.time()
        self.was_blocked = True
        self.blocked_reason = reason

    @property
    def execution_ms(self) -> float:
        if self.finished_at is None:
            return 0
        return round((self.finished_at - self.started_at) * 1000, 2)

    def to_dict(self) -> dict:
        return {
            "entry_id": self.entry_id,
            "session_id": self.session_id,
            "user_role": self.user_role,
            "tool_name": self.tool_name,
            "tool_input": self.tool_input,
            "decision_reason": self.decision_reason,
            "result_summary": self._summarize_result(),
            "error": self.error,
            "was_blocked": self.was_blocked,
            "blocked_reason": self.blocked_reason,
            "execution_ms": self.execution_ms,
            "timestamp": datetime.utcfromtimestamp(self.started_at).isoformat(),
        }

    def _summarize_result(self) -> Optional[str]:
        if self.result is None:
            return None
        result_str = json.dumps(self.result, default=str)
        if len(result_str) > 500:
            return result_str[:500] + "..."
        return result_str


class AIObserver:
    """Observability service for AI tool execution.

    Usage:
        observer = AIObserver(session_id, user_role)
        entry = observer.start(tool_name, tool_input, reason)
        try:
            result = execute_tool(...)
            observer.complete(entry, result)
        except Exception as e:
            observer.fail(entry, str(e))
    """

    def __init__(self, session_id: str, user_role: str = "ai_agent"):
        self.session_id = session_id
        self.user_role = user_role
        self.redis = get_redis()

    def start(self, tool_name: str, tool_input: dict, reason: Optional[str] = None) -> AIAuditEntry:
        """Start tracking a tool execution."""
        entry = AIAuditEntry(
            session_id=self.session_id,
            user_role=self.user_role,
            tool_name=tool_name,
            tool_input=tool_input,
            decision_reason=reason,
        )
        logger.info(
            f"[AI_DECISION] session={self.session_id} role={self.user_role} "
            f"tool={tool_name} input={json.dumps(tool_input, default=str)[:200]}"
        )
        return entry

    def complete(self, entry: AIAuditEntry, result: dict):
        """Mark tool execution as successful."""
        entry.complete(result)
        self._persist(entry)
        logger.info(
            f"[AI_COMPLETE] session={self.session_id} tool={entry.tool_name} "
            f"time={entry.execution_ms}ms success=true"
        )

    def fail(self, entry: AIAuditEntry, error: str):
        """Mark tool execution as failed."""
        entry.fail(error)
        self._persist(entry)
        logger.warning(
            f"[AI_FAIL] session={self.session_id} tool={entry.tool_name} "
            f"time={entry.execution_ms}ms error={error[:100]}"
        )

    def block(self, entry: AIAuditEntry, reason: str):
        """Mark tool execution as blocked by permissions."""
        entry.block(reason)
        self._persist(entry)
        logger.warning(
            f"[AI_BLOCKED] session={self.session_id} tool={entry.tool_name} "
            f"role={self.user_role} reason={reason}"
        )

    def get_session_audit(self, limit: int = 50) -> list[dict]:
        """Get audit trail for a session."""
        key = f"{AUDIT_SESSION_PREFIX}{self.session_id}"
        entries = self.redis.lrange(key, 0, limit - 1)
        return [json.loads(e) for e in entries]

    def get_recent_audit(self, limit: int = 100) -> list[dict]:
        """Get most recent audit entries across all sessions."""
        entry_ids = self.redis.lrange(AUDIT_INDEX_KEY, 0, limit - 1)
        results = []
        for eid in entry_ids:
            raw = self.redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
            if raw:
                results.append(json.loads(raw))
        return results

    def _persist(self, entry: AIAuditEntry):
        """Store audit entry in Redis."""
        try:
            data = json.dumps(entry.to_dict(), default=str)

            # Store entry
            self.redis.set(
                f"{AUDIT_KEY_PREFIX}{entry.entry_id}",
                data,
                ex=60 * 60 * 24 * 7,  # 7 days
            )

            # Add to session list
            session_key = f"{AUDIT_SESSION_PREFIX}{self.session_id}"
            self.redis.lpush(session_key, data)
            self.redis.ltrim(session_key, 0, 199)  # Keep last 200 per session
            self.redis.expire(session_key, 60 * 60 * 24 * 7)

            # Add to global index
            self.redis.lpush(AUDIT_INDEX_KEY, entry.entry_id)
            self.redis.ltrim(AUDIT_INDEX_KEY, 0, MAX_AUDIT_ENTRIES - 1)
        except Exception as e:
            logger.error(f"Audit persist failed: {e}")
