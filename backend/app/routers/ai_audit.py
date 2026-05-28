"""Admin AI Audit Dashboard."""
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
    # Admin tools
    "list_categories": "تصنيفات",
    "create_category": "تصنيفات",
    "update_category": "تصنيفات",
    "delete_category": "تصنيفات",
    "get_monthly_profit": "تقارير",
    "get_cash_flow": "تقارير",
    "get_waste_report": "تقارير",
    "get_notifications": "إشعارات",
    "mark_notification_read": "إشعارات",
    "mark_all_notifications_read": "إشعارات",
    "check_low_stock_alerts": "تنبيهات",
    "check_credit_limit_alerts": "تنبيهات",
    "check_overdue_supplier_alerts": "تنبيهات",
    "scan_anomalies": "تحليلات",
    "detect_revenue_anomaly": "تحليلات",
    "detect_expense_anomaly": "تحليلات",
    "get_business_insights": "تحليلات",
    "why_profit_dropped": "تحليلات",
    "get_top_risks": "تحليلات",
    "get_dashboard_summary": "لوحة التحكم",
    "refresh_daily_summary": "مهام محاسبية",
    "refresh_summary_range": "مهام محاسبية",
    "list_users": "إدارة مستخدمين",
    "create_user": "إدارة مستخدمين",
    "deactivate_user": "إدارة مستخدمين",
    "activate_user": "إدارة مستخدمين",
    "reset_user_password": "إدارة مستخدمين",
    "get_ledger_entries": "قيود محاسبية",
    "get_account_balance": "قيود محاسبية",
    "get_trial_balance": "قيود محاسبية",
}


def _tool_label(tool: str) -> str:
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
        # Admin tools
        "list_categories": "عرض التصنيفات",
        "create_category": "إنشاء تصنيف",
        "update_category": "تعديل تصنيف",
        "delete_category": "حذف تصنيف",
        "get_monthly_profit": "تقرير الأرباح الشهرية",
        "get_cash_flow": "تقرير التدفق النقدي",
        "get_waste_report": "تقرير الهالك",
        "get_notifications": "عرض الإشعارات",
        "mark_notification_read": "تحديد إشعار كمقروء",
        "mark_all_notifications_read": "تحديد الكل كمقروء",
        "check_low_stock_alerts": "فحص تنبيهات المخزون",
        "check_credit_limit_alerts": "فحص تجاوز الائتمان",
        "check_overdue_supplier_alerts": "فحص المدفوعات المتأخرة",
        "scan_anomalies": "فحص الانحرافات",
        "detect_revenue_anomaly": "انحراف الإيرادات",
        "detect_expense_anomaly": "انحراف المصروفات",
        "get_business_insights": "رؤى الأعمال",
        "why_profit_dropped": "تحليل انخفاض الربح",
        "get_top_risks": "أهم المخاطر",
        "get_dashboard_summary": "ملخص لوحة التحكم",
        "refresh_daily_summary": "تحديث الملخص اليومي",
        "refresh_summary_range": "تحديث ملخص فترة",
        "list_users": "عرض المستخدمين",
        "create_user": "إنشاء مستخدم",
        "deactivate_user": "تعطيل مستخدم",
        "activate_user": "تفعيل مستخدم",
        "reset_user_password": "إعادة تعيين كلمة المرور",
        "get_ledger_entries": "عرض القيود",
        "get_account_balance": "رصيد حساب",
        "get_trial_balance": "ميزان المراجعة",
    }
    return labels.get(tool, tool)


def _classify_entry(entry: dict) -> dict:
    tool = entry.get("tool_name", "unknown")
    was_blocked = entry.get("was_blocked", False)
    error = entry.get("error")
    result_summary = entry.get("result_summary", "")

    if was_blocked:
        status, severity, icon = "blocked", "critical", "blocked"
        description = entry.get("blocked_reason", "تم رفض العملية")
    elif error:
        status, severity, icon = "failed", "warning", "warning"
        description = error[:150]
    elif result_summary and '"requires_confirmation"' in result_summary:
        status, severity, icon = "pending_confirmation", "info", "decision"
        description = "بانتظار تأكيد المستخدم"
    else:
        status, severity, icon = "executed", "success", "executed"
        description = _describe_execution(tool, entry.get("tool_input", {}), result_summary)

    return {
        "id": entry.get("entry_id", ""), "timestamp": entry.get("timestamp", ""),
        "status": status, "severity": severity, "icon": icon,
        "tool": tool, "tool_label": _tool_label(tool),
        "category": TOOL_CATEGORIES.get(tool, "أخرى"),
        "role": entry.get("user_role", "ai_agent"),
        "channel": entry.get("channel", "chat"),
        "session_id": entry.get("session_id", ""),
        "description": description,
        "execution_ms": entry.get("execution_ms", 0),
        "details": {"input": entry.get("tool_input", {}), "reason": entry.get("decision_reason"), "blocked_reason": entry.get("blocked_reason")},
    }


def _describe_execution(tool: str, tool_input: dict, result_summary: str) -> str:
    if tool == "create_invoice":
        return f"تم إنشاء فاتورة بـ {len(tool_input.get('items', []))} أصناف"
    elif tool == "record_payment":
        return f"تم تسجيل دفعة {tool_input.get('amount', 0)} جنيه"
    elif tool == "search_products":
        return f'بحث: "{tool_input.get("query", "")}"'
    elif tool == "search_customers":
        return f'بحث عملاء: "{tool_input.get("query", "")}"'
    elif tool == "create_expense":
        return f"تسجيل مصروف '{tool_input.get('name', '')}' بمبلغ {tool_input.get('amount', 0)} جنيه"
    elif tool == "set_customer_opening_balance":
        return f"رصيد أول المدة {tool_input.get('amount', 0)} جنيه للعميل #{tool_input.get('customer_id', '')}"
    elif tool == "set_supplier_opening_balance":
        return f"رصيد أول المدة {tool_input.get('amount', 0)} جنيه للمورد #{tool_input.get('supplier_id', '')}"
    elif tool == "set_cash_opening_balance":
        return f"رصيد صندوق أول المدة {tool_input.get('amount', 0)} جنيه"
    elif tool == "set_opening_inventory":
        return f"جرد أول المدة: {tool_input.get('quantity', 0)} وحدة من المنتج #{tool_input.get('product_id', '')}"
    elif tool == "create_purchase_invoice":
        return f"إنشاء فاتورة مشتريات بـ {len(tool_input.get('items', []))} أصناف"
    elif tool == "create_sales_return":
        return f"مرتجع {len(tool_input.get('items', []))} أصناف من الفاتورة #{tool_input.get('invoice_id', '')}"
    elif tool == "create_purchase_return":
        return f"مرتجع مشتريات: {len(tool_input.get('items', []))} أصناف"
    elif tool == "create_supplier":
        return f"إنشاء مورد: {tool_input.get('name', '')}"
    elif tool == "search_suppliers":
        return f'بحث موردين: "{tool_input.get("query", "")}"'
    elif tool == "create_product":
        return f"إنشاء منتج: {tool_input.get('name', '')}"
    elif tool == "get_product":
        return f"عرض تفاصيل المنتج #{tool_input.get('product_id', '')}"
    elif tool == "cancel_invoice":
        return f"إلغاء الفاتورة #{tool_input.get('invoice_id', '')}"
    elif tool == "refund_payment":
        return f"رد مبلغ {tool_input.get('amount', 0)} جنيه"
    elif tool == "transfer_stock":
        return f"نقل {tool_input.get('quantity', 0)} وحدة بين المخازن"
    elif tool == "confirm_transaction":
        return "تم تأكيد عملية معلقة"
    # Admin tools
    elif tool == "create_category":
        return f"إنشاء تصنيف: {tool_input.get('name', '')}"
    elif tool == "delete_category":
        return f"حذف التصنيف #{tool_input.get('category_id', '')}"
    elif tool == "create_user":
        return f"إنشاء مستخدم: {tool_input.get('username', '')} ({tool_input.get('role', '')})"
    elif tool == "deactivate_user":
        return f"تعطيل المستخدم #{tool_input.get('user_id', '')}"
    elif tool == "activate_user":
        return f"تفعيل المستخدم #{tool_input.get('user_id', '')}"
    elif tool == "reset_user_password":
        return f"إعادة تعيين كلمة مرور المستخدم #{tool_input.get('user_id', '')}"
    elif tool == "refresh_daily_summary":
        return f"تحديث الملخص المالي ليوم {tool_input.get('target_date', 'اليوم')}"
    elif tool == "refresh_summary_range":
        return f"تحديث الملخص من {tool_input.get('start_date', '')} إلى {tool_input.get('end_date', 'اليوم')}"
    elif tool.startswith("get_") or tool.startswith("list_") or tool.startswith("scan_") or tool.startswith("detect_") or tool.startswith("check_") or tool.startswith("why_") or tool.startswith("mark_"):
        return "تم الاستعلام بنجاح"
    return "تم التنفيذ"


def _load_entries_in_window(hours: int, limit: int = 999) -> list[dict]:
    """Load audit entries within the given time window."""
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, limit)
    cutoff = (datetime.utcnow() - timedelta(hours=hours)).isoformat()
    entries = []
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
        entries.append(entry)
    return entries


@router.get("/feed")
async def get_activity_feed(
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None),
    role_filter: Optional[str] = Query(None),
    category_filter: Optional[str] = Query(None),
    channel_filter: Optional[str] = Query(None),
    session_id: Optional[str] = Query(None),
    _current_user=Depends(get_current_admin_user),
):
    redis = get_redis()
    if session_id:
        raw_entries = redis.lrange(f"{AUDIT_SESSION_PREFIX}{session_id}", 0, limit * 2)
    else:
        entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, limit * 3)
        raw_entries = [redis.get(f"{AUDIT_KEY_PREFIX}{eid}") for eid in entry_ids]
        raw_entries = [r for r in raw_entries if r]

    feed_items = []
    for raw in raw_entries:
        try:
            entry = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
            item = _classify_entry(entry)
            if status_filter and item["status"] != status_filter:
                continue
            if role_filter and item["role"] != role_filter:
                continue
            if category_filter and item["category"] != category_filter:
                continue
            if channel_filter and item["channel"] != channel_filter:
                continue
            feed_items.append(item)
            if len(feed_items) >= limit:
                break
        except Exception:
            continue

    return {"feed": feed_items, "total": len(feed_items), "filters_applied": {"status": status_filter, "role": role_filter, "category": category_filter, "channel": channel_filter, "session_id": session_id}}


@router.get("/stats")
async def get_audit_stats(hours: int = Query(24, ge=1, le=168), _current_user=Depends(get_current_admin_user)):
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 999)
    cutoff = (datetime.utcnow() - timedelta(hours=hours)).isoformat()
    stats = {"by_status": {"executed": 0, "blocked": 0, "failed": 0, "pending_confirmation": 0}, "by_role": {}, "by_category": {}, "by_tool": {}, "by_channel": {}, "performance": {"total_calls": 0, "avg_execution_ms": 0, "max_execution_ms": 0}, "timeline": []}
    total_ms, max_ms, hourly_buckets = 0, 0, {}

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
        item = _classify_entry(entry)
        stats["performance"]["total_calls"] += 1
        status = item["status"]
        if status in stats["by_status"]:
            stats["by_status"][status] += 1
        role = item["role"]
        stats["by_role"][role] = stats["by_role"].get(role, 0) + 1
        cat = item["category"]
        stats["by_category"][cat] = stats["by_category"].get(cat, 0) + 1
        tool = item["tool"]
        stats["by_tool"][tool] = stats["by_tool"].get(tool, 0) + 1
        channel = item.get("channel", "chat")
        stats["by_channel"][channel] = stats["by_channel"].get(channel, 0) + 1
        ms = entry.get("execution_ms", 0)
        total_ms += ms
        max_ms = max(max_ms, ms)
        hour_key = entry.get("timestamp", "")[:13]
        if hour_key not in hourly_buckets:
            hourly_buckets[hour_key] = {"executed": 0, "blocked": 0, "failed": 0}
        if status in hourly_buckets[hour_key]:
            hourly_buckets[hour_key][status] += 1

    total_calls = stats["performance"]["total_calls"]
    stats["performance"]["avg_execution_ms"] = round(total_ms / total_calls, 1) if total_calls > 0 else 0
    stats["performance"]["max_execution_ms"] = round(max_ms, 1)
    stats["by_tool"] = dict(sorted(stats["by_tool"].items(), key=lambda x: x[1], reverse=True)[:10])
    for hour_key in sorted(hourly_buckets.keys()):
        stats["timeline"].append({"hour": hour_key, **hourly_buckets[hour_key]})
    stats["period_hours"] = hours
    return stats


@router.get("/sessions")
async def get_active_sessions(limit: int = Query(20, ge=1, le=100), _current_user=Depends(get_current_admin_user)):
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
            sessions[sid] = {"session_id": sid, "role": entry.get("user_role", "unknown"), "channel": entry.get("channel", "chat"), "first_seen": entry.get("timestamp", ""), "last_seen": entry.get("timestamp", ""), "total_actions": 0, "blocked_actions": 0, "tools_used": set()}
        s = sessions[sid]
        s["total_actions"] += 1
        s["last_seen"] = entry.get("timestamp", s["last_seen"])
        if entry.get("was_blocked"):
            s["blocked_actions"] += 1
        s["tools_used"].add(entry.get("tool_name", ""))

    result = []
    for s in sessions.values():
        s["tools_used"] = list(s["tools_used"])
        s["unique_tools"] = len(s["tools_used"])
        result.append(s)
    result.sort(key=lambda x: x["last_seen"], reverse=True)
    return {"sessions": result[:limit], "total": len(result)}


@router.get("/blocked")
async def get_blocked_actions(limit: int = Query(50, ge=1, le=200), _current_user=Depends(get_current_admin_user)):
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
        blocked_items.append({"id": entry.get("entry_id", ""), "timestamp": entry.get("timestamp", ""), "session_id": entry.get("session_id", ""), "role": entry.get("user_role", "unknown"), "channel": entry.get("channel", "chat"), "tool": entry.get("tool_name", ""), "tool_label": _tool_label(entry.get("tool_name", "")), "reason": entry.get("blocked_reason", ""), "attempted_input": entry.get("tool_input", {})})
        if len(blocked_items) >= limit:
            break
    return {"blocked_actions": blocked_items, "total": len(blocked_items), "severity": "critical" if len(blocked_items) > 10 else "normal"}


@router.get("/performance")
async def get_performance_metrics(hours: int = Query(24, ge=1, le=168), _current_user=Depends(get_current_admin_user)):
    redis = get_redis()
    entry_ids = redis.lrange(AUDIT_INDEX_KEY, 0, 999)
    cutoff = (datetime.utcnow() - timedelta(hours=hours)).isoformat()
    tool_perf = {}
    for eid in entry_ids:
        raw = redis.get(f"{AUDIT_KEY_PREFIX}{eid}")
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except Exception:
            continue
        if entry.get("timestamp", "") < cutoff or entry.get("was_blocked"):
            continue
        tool = entry.get("tool_name", "unknown")
        ms = entry.get("execution_ms", 0)
        if tool not in tool_perf:
            tool_perf[tool] = []
        tool_perf[tool].append(ms)

    metrics = []
    for tool, times in tool_perf.items():
        times.sort()
        count = len(times)
        avg = sum(times) / count if count else 0
        p95 = times[int(count * 0.95)] if count > 5 else (times[-1] if times else 0)
        metrics.append({"tool": tool, "tool_label": _tool_label(tool), "call_count": count, "avg_ms": round(avg, 1), "p95_ms": round(p95, 1), "max_ms": round(max(times), 1) if times else 0, "health": "slow" if avg > 2000 else ("normal" if avg > 500 else "fast")})
    metrics.sort(key=lambda x: x["avg_ms"], reverse=True)
    all_times = [ms for times in tool_perf.values() for ms in times]
    overall_avg = sum(all_times) / len(all_times) if all_times else 0
    return {"period_hours": hours, "overall_avg_ms": round(overall_avg, 1), "total_executions": len(all_times), "tools": metrics}


# ─── New Analytics Endpoints ───────────────────────────────────────────────────


@router.get("/analytics/latency")
async def get_latency_analytics(
    hours: int = Query(24, ge=1, le=168),
    channel: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    _current_user=Depends(get_current_admin_user),
):
    """Per-tool latency with p50, p75, p95, p99 percentiles."""
    entries = _load_entries_in_window(hours)
    tool_times: dict[str, list[float]] = {}

    for entry in entries:
        if entry.get("was_blocked"):
            continue
        if channel and entry.get("channel", "chat") != channel:
            continue
        if role and entry.get("user_role", "") != role:
            continue
        tool = entry.get("tool_name", "unknown")
        ms = entry.get("execution_ms", 0)
        tool_times.setdefault(tool, []).append(ms)

    def _percentile(sorted_list: list[float], pct: float) -> float:
        if not sorted_list:
            return 0
        idx = int(len(sorted_list) * pct)
        idx = min(idx, len(sorted_list) - 1)
        return round(sorted_list[idx], 1)

    metrics = []
    for tool, times in tool_times.items():
        times.sort()
        count = len(times)
        metrics.append({
            "tool": tool,
            "tool_label": _tool_label(tool),
            "call_count": count,
            "avg_ms": round(sum(times) / count, 1) if count else 0,
            "p50_ms": _percentile(times, 0.50),
            "p75_ms": _percentile(times, 0.75),
            "p95_ms": _percentile(times, 0.95),
            "p99_ms": _percentile(times, 0.99),
            "min_ms": round(times[0], 1) if times else 0,
            "max_ms": round(times[-1], 1) if times else 0,
        })

    metrics.sort(key=lambda x: x["p95_ms"], reverse=True)
    all_times = sorted(ms for times in tool_times.values() for ms in times)
    return {
        "period_hours": hours,
        "filters": {"channel": channel, "role": role},
        "global_p50_ms": _percentile(all_times, 0.50),
        "global_p95_ms": _percentile(all_times, 0.95),
        "global_avg_ms": round(sum(all_times) / len(all_times), 1) if all_times else 0,
        "total_executions": len(all_times),
        "tools": metrics,
    }


@router.get("/analytics/success-rates")
async def get_success_rates(
    hours: int = Query(24, ge=1, le=168),
    channel: Optional[str] = Query(None),
    _current_user=Depends(get_current_admin_user),
):
    """Success/failure/blocked rates overall and per-tool."""
    entries = _load_entries_in_window(hours)
    tool_stats: dict[str, dict] = {}
    totals = {"executed": 0, "failed": 0, "blocked": 0, "pending_confirmation": 0}

    for entry in entries:
        if channel and entry.get("channel", "chat") != channel:
            continue
        item = _classify_entry(entry)
        status = item["status"]
        tool = item["tool"]

        if status in totals:
            totals[status] += 1

        if tool not in tool_stats:
            tool_stats[tool] = {"tool": tool, "tool_label": _tool_label(tool), "executed": 0, "failed": 0, "blocked": 0, "pending_confirmation": 0}
        if status in tool_stats[tool]:
            tool_stats[tool][status] += 1

    total_all = sum(totals.values())
    overall_rates = {
        "total_calls": total_all,
        "success_rate": round(totals["executed"] / total_all * 100, 1) if total_all else 0,
        "failure_rate": round(totals["failed"] / total_all * 100, 1) if total_all else 0,
        "blocked_rate": round(totals["blocked"] / total_all * 100, 1) if total_all else 0,
        "confirmation_rate": round(totals["pending_confirmation"] / total_all * 100, 1) if total_all else 0,
    }

    per_tool = []
    for stats in tool_stats.values():
        tool_total = stats["executed"] + stats["failed"] + stats["blocked"] + stats["pending_confirmation"]
        per_tool.append({
            **stats,
            "total": tool_total,
            "success_rate": round(stats["executed"] / tool_total * 100, 1) if tool_total else 0,
            "failure_rate": round(stats["failed"] / tool_total * 100, 1) if tool_total else 0,
        })
    per_tool.sort(key=lambda x: x["total"], reverse=True)

    return {
        "period_hours": hours,
        "filters": {"channel": channel},
        "overall": overall_rates,
        "by_status": totals,
        "per_tool": per_tool[:20],
    }


@router.get("/analytics/role-usage")
async def get_role_usage(
    hours: int = Query(24, ge=1, le=168),
    _current_user=Depends(get_current_admin_user),
):
    """Per-role detailed usage analytics."""
    entries = _load_entries_in_window(hours)
    role_data: dict[str, dict] = {}

    for entry in entries:
        role = entry.get("user_role", "ai_agent")
        if role not in role_data:
            role_data[role] = {
                "role": role,
                "total_calls": 0,
                "executed": 0,
                "failed": 0,
                "blocked": 0,
                "total_ms": 0,
                "tools_used": {},
                "categories_used": {},
                "channels_used": {},
            }
        rd = role_data[role]
        rd["total_calls"] += 1

        item = _classify_entry(entry)
        status = item["status"]
        if status == "executed":
            rd["executed"] += 1
        elif status == "failed":
            rd["failed"] += 1
        elif status == "blocked":
            rd["blocked"] += 1

        rd["total_ms"] += entry.get("execution_ms", 0)

        tool = entry.get("tool_name", "unknown")
        rd["tools_used"][tool] = rd["tools_used"].get(tool, 0) + 1

        cat = TOOL_CATEGORIES.get(tool, "أخرى")
        rd["categories_used"][cat] = rd["categories_used"].get(cat, 0) + 1

        ch = entry.get("channel", "chat")
        rd["channels_used"][ch] = rd["channels_used"].get(ch, 0) + 1

    roles = []
    for rd in role_data.values():
        total = rd["total_calls"]
        roles.append({
            "role": rd["role"],
            "total_calls": total,
            "success_rate": round(rd["executed"] / total * 100, 1) if total else 0,
            "blocked_rate": round(rd["blocked"] / total * 100, 1) if total else 0,
            "avg_latency_ms": round(rd["total_ms"] / total, 1) if total else 0,
            "top_tools": dict(sorted(rd["tools_used"].items(), key=lambda x: x[1], reverse=True)[:5]),
            "categories": rd["categories_used"],
            "channels": rd["channels_used"],
        })
    roles.sort(key=lambda x: x["total_calls"], reverse=True)

    return {
        "period_hours": hours,
        "roles": roles,
    }


@router.get("/analytics/channel-comparison")
async def get_channel_comparison(
    hours: int = Query(24, ge=1, le=168),
    _current_user=Depends(get_current_admin_user),
):
    """Voice vs chat performance comparison."""
    entries = _load_entries_in_window(hours)
    channel_data: dict[str, dict] = {}

    for entry in entries:
        ch = entry.get("channel", "chat")
        if ch not in channel_data:
            channel_data[ch] = {
                "channel": ch,
                "total_calls": 0,
                "executed": 0,
                "failed": 0,
                "blocked": 0,
                "times": [],
                "tools_used": {},
                "roles": {},
            }
        cd = channel_data[ch]
        cd["total_calls"] += 1

        item = _classify_entry(entry)
        status = item["status"]
        if status == "executed":
            cd["executed"] += 1
        elif status == "failed":
            cd["failed"] += 1
        elif status == "blocked":
            cd["blocked"] += 1

        ms = entry.get("execution_ms", 0)
        cd["times"].append(ms)

        tool = entry.get("tool_name", "unknown")
        cd["tools_used"][tool] = cd["tools_used"].get(tool, 0) + 1

        role = entry.get("user_role", "ai_agent")
        cd["roles"][role] = cd["roles"].get(role, 0) + 1

    def _percentile(sorted_list: list[float], pct: float) -> float:
        if not sorted_list:
            return 0
        idx = min(int(len(sorted_list) * pct), len(sorted_list) - 1)
        return round(sorted_list[idx], 1)

    channels = []
    for cd in channel_data.values():
        total = cd["total_calls"]
        times = sorted(cd["times"])
        channels.append({
            "channel": cd["channel"],
            "total_calls": total,
            "success_rate": round(cd["executed"] / total * 100, 1) if total else 0,
            "failure_rate": round(cd["failed"] / total * 100, 1) if total else 0,
            "blocked_rate": round(cd["blocked"] / total * 100, 1) if total else 0,
            "avg_ms": round(sum(times) / len(times), 1) if times else 0,
            "p50_ms": _percentile(times, 0.50),
            "p95_ms": _percentile(times, 0.95),
            "top_tools": dict(sorted(cd["tools_used"].items(), key=lambda x: x[1], reverse=True)[:5]),
            "roles": cd["roles"],
        })
    channels.sort(key=lambda x: x["total_calls"], reverse=True)

    return {
        "period_hours": hours,
        "channels": channels,
    }
