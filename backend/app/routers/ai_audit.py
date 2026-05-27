"""Admin AI Audit Dashboard.

Provides structured, categorized view of AI activity — not raw logs.
Designed for admin oversight, compliance, and debugging.
"""
from fastapi import APIRouter, Depends, Query
from typing import Optional
from datetime import datetime, timedelta
from app.core.deps import get_current_admin_user
from app.ai.observability import AIObserver
from app.core.redis import get_redis
import json

router = APIRouter()

AUDIT_KEY_PREFIX = "ai:audit:"
AUDIT_INDEX_KEY = "ai:audit:index"
AUDIT_SESSION_PREFIX = "ai:audit:session:"

# Tool categories for human-readable grouping
TOOL_CATEGORIES = {
    "get_today_sales": "مبيعات",
    "get_customer_info": "عملاء",
    "get_customer_history": "عملاء",
    "get_top_selling_products": "مبيعات",
    "get_unpaid_invoices": "مالية",
    "get_stock_level": "مخزون",
    "get_low_stock_items": "مخزون",
    "get_stock_movement_history": "مخزون",
    "get_warehouse_summary": "مخزون",
    "get_dead_stock": "مخزون",
    "get_stock_valuation": "مخزون",
    "get_profit_and_loss": "مالية",
    "get_cash_balance": "مالية",
    "get_receivables_summary": "مالية",
    "get_payables_summary": "مالية",
    "get_expense_breakdown": "مالية",
    "get_daily_revenue": "مالية",
    "demand_forecast": "تحليلات",
    "search_products": "بحث",
    "search_customers": "بحث",
    "create_invoice": "فواتير",
    "cancel_invoice": "فواتير",
    "apply_discount": "فواتير",
    "record_payment": "مدفوعات",
    "refund_payment": "مدفوعات",
    "update_stock": "مخزون",
    "transfer_stock": "مخزون",
    "adjust_stock": "مخزون",
    "create_customer": "عملاء",
    "update_customer": "عملاء",
    "confirm_transaction": "تأكيدات",
    # Extended tools
    "set_customer_opening_balance": "أرصدة افتتاحية",
    "set_supplier_opening_balance": "أرصدة افتتاحية",
    "set_cash_opening_balance": "أرصدة افتتاحية",
    "set_opening_inventory": "أرصدة افتتاحية",
    "get_opening_balances": "أرصدة افتتاحية",
    "create_expense": "مصروفات",
    "list_expenses": "مصروفات",
    "get_expense_summary": "مصروفات",
    "list_sales_invoices": "فواتير",
    "get_sales_invoice": "فواتير",
    "get_invoice_items": "فواتير",
    "create_sales_return": "مرتجعات",
    "list_purchase_invoices": "مشتريات",
    "get_purchase_invoice": "مشتريات",
    "get_purchase_items": "مشتريات",
    "create_purchase_invoice": "مشتريات",
    "create_purchase_return": "مرتجعات",
    "create_supplier": "موردين",
    "update_supplier": "موردين",
    "search_suppliers": "موردين",
    "create_product": "منتجات",
    "update_product": "منتجات",
    "get_product": "منتجات",
}


def _classify_entry(entry: dict) -> dict:
    """Transform a raw audit entry into a structured feed item."""
    tool = entry.get("tool_name", "unknown")
    was_blocked = entry.get("was_blocked", False)
    error = entry.get("error")
    result_summary = entry.get("result_summary", "")

    # Determine status and severity
    if was_blocked:
        status = "blocked"
        severity = "critical"
        icon = "blocked"
        description = entry.get("blocked_reason", "تم رفض العملية")
    elif error:
        status = "failed"
        severity = "warning"
        icon = "warning"
        description = error[:150]
    elif result_summary and '"requires_confirmation"' in result_summary:
        status = "pending_confirmation"
        severity = "info"
        icon = "decision"
        description = "بانتظار تأكيد المستخدم"
    else:
        status = "executed"
        severity = "success"
        icon = "executed"
        description = _describe_execution(tool, entry.get("tool_input", {}), result_summary)

    return {
        "id": entry.get("entry_id", ""),
        "timestamp": entry.get("timestamp", ""),
        "status": status,
        "severity": severity,
        "icon": icon,
        "tool": tool,
        "tool_label": _tool_label(tool),
        "category": TOOL_CATEGORIES.get(tool, "أخرى"),
        "role": entry.get("user_role", "ai_agent"),
        "session_id": entry.get("session_id", ""),
        "description": description,
        "execution_ms": entry.get("execution_ms", 0),
        "details": {
            "input": entry.get("tool_input", {}),
            "reason": entry.get("decision_reason"),
            "blocked_reason": entry.get("blocked_reason"),
        },
    }


def _tool_label(tool: str) -> str:
    """Human-readable Arabic label for tool name."""
    labels = {
        "get_today_sales": "عرض مبيعات اليوم",
        "get_customer_info": "عرض بيانات عميل",
        "get_customer_history": "سجل تعاملات عميل",
        "get_top_selling_products": "أكثر المنتجات مبيعاً",
        "get_unpaid_invoices": "فواتير غير مدفوعة",
        "get_stock_level": "مستوى المخزون",
        "get_low_stock_items": "أصناف منخفضة",
        "get_cash_balance": "رصيد الكاش",
        "get_profit_and_loss": "أرباح وخسائر",
        "search_products": "بحث منتجات",
        "search_customers": "بحث عملاء",
        "create_invoice": "إنشاء فاتورة",
        "cancel_invoice": "إلغاء فاتورة",
        "record_payment": "تسجيل دفعة",
        "refund_payment": "رد مبلغ",
        "update_stock": "تحديث مخزون",
        "transfer_stock": "نقل بضاعة",
        "adjust_stock": "تعديل مخزون",
        "create_customer": "إنشاء عميل",
        "update_customer": "تعديل عميل",
        "confirm_transaction": "تأكيد عملية",
        "demand_forecast": "توقع الطلب",
        "apply_discount": "تطبيق خصم",
        # Extended tools
        "set_customer_opening_balance": "رصيد أول المدة - عميل",
        "set_supplier_opening_balance": "رصيد أول المدة - مورد",
        "set_cash_opening_balance": "رصيد أول المدة - صندوق",
        "set_opening_inventory": "جرد أول المدة",
        "get_opening_balances": "عرض الأرصدة الافتتاحية",
        "create_expense": "تسجيل مصروف",
        "list_expenses": "عرض المصروفات",
        "get_expense_summary": "ملخص المصروفات",
        "list_sales_invoices": "عرض فواتير المبيعات",
        "get_sales_invoice": "عرض فاتورة مبيعات",
        "get_invoice_items": "أصناف الفاتورة",
        "create_sales_return": "مرتجع مبيعات",
        "list_purchase_invoices": "عرض فواتير المشتريات",
        "get_purchase_invoice": "عرض فاتورة مشتريات",
        "get_purchase_items": "أصناف فاتورة المشتريات",
        "create_purchase_invoice": "إنشاء فاتورة مشتريات",
        "create_purchase_return": "مرتجع مشتريات",
        "create_supplier": "إنشاء مورد",
        "update_supplier": "تعديل مورد",
        "search_suppliers": "بحث موردين",
        "create_product": "إنشاء منتج",
        "update_product": "تعديل منتج",
        "get_product": "عرض تفاصيل منتج",
    }
    return labels.get(tool, tool)


def _describe_execution(tool: str, tool_input: dict, result_summary: str) -> str:
    """Generate human-readable description of what happened."""
    if tool == "create_invoice":
        items_count = len(tool_input.get("items", []))
        return f"تم إنشاء فاتورة بـ {items_count} أصناف"
    elif tool == "record_payment":
        amount = tool_input.get("amount", 0)
        return f"تم تسجيل دفعة {amount} جنيه"
    elif tool == "search_products":
        query = tool_input.get("query", "")
        return f'بحث: "{query}"'
    elif tool == "search_customers":
        query = tool_input.get("query", "")
        return f'بحث عملاء: "{query}"'
    elif tool == "get_stock_level":
        pid = tool_input.get("product_id", "")
        return f"استعلام مخزون المنتج #{pid}"
    elif tool == "transfer_stock":
        qty = tool_input.get("quantity", 0)
        return f"نقل {qty} وحدة بين المخازن"
    elif tool == "cancel_invoice":
        inv_id = tool_input.get("invoice_id", "")
        return f"إلغاء الفاتورة #{inv_id}"
    elif tool == "refund_payment":
        amount = tool_input.get("amount", 0)
        return f"رد مبلغ {amount} جنيه"
    elif tool == "confirm_transaction":
        return "تم تأكيد عملية معلقة"
    # Extended tool descriptions
    elif tool == "create_expense":
        name = tool_input.get("name", "")
        amount = tool_input.get("amount", 0)
        return f"تسجيل مصروف '{name}' بمبلغ {amount} جنيه"
    elif tool == "set_customer_opening_balance":
        cid = tool_input.get("customer_id", "")
        amount = tool_input.get("amount", 0)
        return f"رصيد أول المدة {amount} جنيه للعميل #{cid}"
    elif tool == "set_supplier_opening_balance":
        sid = tool_input.get("supplier_id", "")
        amount = tool_input.get("amount", 0)
        return f"رصيد أول المدة {amount} جنيه للمورد #{sid}"
    elif tool == "set_cash_opening_balance":
        amount = tool_input.get("amount", 0)
        return f"رصيد صندوق أول المدة {amount} جنيه"
    elif tool == "set_opening_inventory":
        pid = tool_input.get("product_id", "")
        qty = tool_input.get("quantity", 0)
        return f"جرد أول المدة: {qty} وحدة من المنتج #{pid}"
    elif tool == "create_purchase_invoice":
        items_count = len(tool_input.get("items", []))
        return f"إنشاء فاتورة مشتريات بـ {items_count} أصناف"
    elif tool == "create_sales_return":
        items_count = len(tool_input.get("items", []))
        inv_id = tool_input.get("invoice_id", "")
        return f"مرتجع {items_count} أصناف من الفاتورة #{inv_id}"
    elif tool == "create_purchase_return":
        items_count = len(tool_input.get("items", []))
        return f"مرتجع مشتريات: {items_count} أصناف"
    elif tool == "create_supplier":
        name = tool_input.get("name", "")
        return f"إنشاء مورد: {name}"
    elif tool == "update_supplier":
        sid = tool_input.get("supplier_id", "")
        return f"تعديل المورد #{sid}"
    elif tool == "search_suppliers":
        query = tool_input.get("query", "")
        return f'بحث موردين: "{query}"'
    elif tool == "create_product":
        name = tool_input.get("name", "")
        return f"إنشاء منتج: {name}"
    elif tool == "update_product":
        pid = tool_input.get("product_id", "")
        return f"تعديل المنتج #{pid}"
    elif tool == "get_product":
        pid = tool_input.get("product_id", "")
        return f"عرض تفاصيل المنتج #{pid}"
    elif tool.startswith("get_") or tool.startswith("list_"):
        return "تم الاستعلام بنجاح"
    return "تم التنفيذ"


@router.get("/feed")
async def get_activity_feed(
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None, description="Filter: executed, blocked, failed, pending_confirmation"),
    role_filter: Optional[str] = Query(None, description="Filter by role"),
    category_filter: Optional[str] = Query(None, description="Filter by category"),
    session_id: Optional[str] = Query(None, description="Filter by session"),
    _current_user=Depends(get_current_admin_user),
):
    """AI Activity Feed - structured, categorized view of all AI decisions."""
    redis = get_redis()

    # Get entries from the appropriate source
    if session_id:
        raw_entries = redis.lrange(f"{AUDIT_SESSION_PREFIX}{session_id}", 0, limit * 2)
    else:
        entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, limit * 3)
        raw_entries = []
        for eid in entry_ids:
            raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
            if raw:
                raw_entries.append(raw)

    # Parse and classify
    feed_items = []
    for raw in raw_entries:
        try:
            entry = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
            item = _classify_entry(entry)

            # Apply filters
            if status_filter and item["status"] != status_filter:
                continue
            if role_filter and item["role"] != role_filter:
                continue
            if category_filter and item["category"] != category_filter:
                continue

            feed_items.append(item)

            if len(feed_items) >= limit:
                break
        except Exception:
            continue

    return {
        "feed": feed_items,
        "total": len(feed_items),
        "filters_applied": {
            "status": status_filter,
            "role": role_filter,
            "category": category_filter,
            "session_id": session_id,
        },
    }


@router.get("/stats")
async def get_audit_stats(
    hours: int = Query(24, ge=1, le=168),
    _current_user=Depends(get_current_admin_user),
):
    """AI Activity Statistics - aggregated counts by status, role, category, and tool."""
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 999)

    cutoff = (datetime.utcnow() - timedelta(hours=hours)).isoformat()

    stats = {
        "by_status": {"executed": 0, "blocked": 0, "failed": 0, "pending_confirmation": 0},
        "by_role": {},
        "by_category": {},
        "by_tool": {},
        "performance": {"total_calls": 0, "avg_execution_ms": 0, "max_execution_ms": 0},
        "timeline": [],
    }

    total_ms = 0
    max_ms = 0
    hourly_buckets = {}

    for eid in entry_ids:
        raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue

        timestamp = entry.get("timestamp", "")
        if timestamp < cutoff:
            continue

        item = _classify_entry(entry)
        stats["performance"]["total_calls"] += 1

        # By status
        status = item["status"]
        if status in stats["by_status"]:
            stats["by_status"][status] += 1

        # By role
        role = item["role"]
        stats["by_role"][role] = stats["by_role"].get(role, 0) + 1

        # By category
        cat = item["category"]
        stats["by_category"][cat] = stats["by_category"].get(cat, 0) + 1

        # By tool (top 10)
        tool = item["tool"]
        stats["by_tool"][tool] = stats["by_tool"].get(tool, 0) + 1

        # Performance
        ms = entry.get("execution_ms", 0)
        total_ms += ms
        max_ms = max(max_ms, ms)

        # Timeline (hourly buckets)
        hour_key = timestamp[:13] if len(timestamp) >= 13 else "unknown"
        if hour_key not in hourly_buckets:
            hourly_buckets[hour_key] = {"executed": 0, "blocked": 0, "failed": 0}
        if status in hourly_buckets[hour_key]:
            hourly_buckets[hour_key][status] += 1

    # Finalize
    total_calls = stats["performance"]["total_calls"]
    stats["performance"]["avg_execution_ms"] = round(total_ms / total_calls, 1) if total_calls > 0 else 0
    stats["performance"]["max_execution_ms"] = round(max_ms, 1)

    # Sort tool usage
    stats["by_tool"] = dict(sorted(stats["by_tool"].items(), key=lambda x: x[1], reverse=True)[:10])

    # Build timeline (sorted)
    for hour_key in sorted(hourly_buckets.keys()):
        stats["timeline"].append({
            "hour": hour_key,
            **hourly_buckets[hour_key],
        })

    stats["period_hours"] = hours

    return stats


@router.get("/sessions")
async def get_active_sessions(
    limit: int = Query(20, ge=1, le=100),
    _current_user=Depends(get_current_admin_user),
):
    """List active AI sessions with summary stats."""
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 499)

    sessions = {}
    for eid in entry_ids:
        raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue

        sid = entry.get("session_id", "unknown")
        if sid not in sessions:
            sessions[sid] = {
                "session_id": sid,
                "role": entry.get("user_role", "unknown"),
                "first_seen": entry.get("timestamp", ""),
                "last_seen": entry.get("timestamp", ""),
                "total_actions": 0,
                "blocked_actions": 0,
                "tools_used": set(),
            }

        s = sessions[sid]
        s["total_actions"] += 1
        s["last_seen"] = entry.get("timestamp", s["last_seen"])
        if entry.get("was_blocked"):
            s["blocked_actions"] += 1
        s["tools_used"].add(entry.get("tool_name", ""))

    # Convert sets to lists and sort by recency
    result = []
    for s in sessions.values():
        s["tools_used"] = list(s["tools_used"])
        s["unique_tools"] = len(s["tools_used"])
        result.append(s)

    result.sort(key=lambda x: x["last_seen"], reverse=True)
    return {"sessions": result[:limit], "total": len(result)}


@router.get("/blocked")
async def get_blocked_actions(
    limit: int = Query(50, ge=1, le=200),
    _current_user=Depends(get_current_admin_user),
):
    """Security view: all blocked AI actions (permission denied / amount exceeded)."""
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 999)

    blocked_items = []
    for eid in entry_ids:
        raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue

        if not entry.get("was_blocked"):
            continue

        blocked_items.append({
            "id": entry.get("entry_id", ""),
            "timestamp": entry.get("timestamp", ""),
            "session_id": entry.get("session_id", ""),
            "role": entry.get("user_role", "unknown"),
            "tool": entry.get("tool_name", ""),
            "tool_label": _tool_label(entry.get("tool_name", "")),
            "reason": entry.get("blocked_reason", ""),
            "attempted_input": entry.get("tool_input", {}),
        })

        if len(blocked_items) >= limit:
            break

    return {
        "blocked_actions": blocked_items,
        "total": len(blocked_items),
        "severity": "critical" if len(blocked_items) > 10 else "normal",
    }


@router.get("/performance")
async def get_performance_metrics(
    hours: int = Query(24, ge=1, le=168),
    _current_user=Depends(get_current_admin_user),
):
    """Performance metrics: slowest tools, average latency, throughput."""
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 999)

    cutoff = (datetime.utcnow() - timedelta(hours=hours)).isoformat()

    tool_perf = {}  # tool -> [list of ms values]

    for eid in entry_ids:
        raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue

        if entry.get("timestamp", "") < cutoff:
            continue
        if entry.get("was_blocked"):
            continue

        tool = entry.get("tool_name", "unknown")
        ms = entry.get("execution_ms", 0)

        if tool not in tool_perf:
            tool_perf[tool] = []
        tool_perf[tool].append(ms)

    # Build per-tool metrics
    metrics = []
    for tool, times in tool_perf.items():
        times.sort()
        count = len(times)
        avg = sum(times) / count if count else 0
        p95 = times[int(count * 0.95)] if count > 5 else (times[-1] if times else 0)

        metrics.append({
            "tool": tool,
            "tool_label": _tool_label(tool),
            "call_count": count,
            "avg_ms": round(avg, 1),
            "p95_ms": round(p95, 1),
            "max_ms": round(max(times), 1) if times else 0,
            "health": "slow" if avg > 2000 else ("normal" if avg > 500 else "fast"),
        })

    metrics.sort(key=lambda x: x["avg_ms"], reverse=True)

    all_times = [ms for times in tool_perf.values() for ms in times]
    overall_avg = sum(all_times) / len(all_times) if all_times else 0

    return {
        "period_hours": hours,
        "overall_avg_ms": round(overall_avg, 1),
        "total_executions": len(all_times),
        "tools": metrics,
    }
