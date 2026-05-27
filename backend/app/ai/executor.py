import json
from sqlalchemy.orm import Session
from app.ai.safety.transaction_guard import TransactionGuard, SENSITIVE_OPERATIONS
from app.ai.safety.idempotency import IdempotencyGuard
from app.ai.safety.permissions import AIPermissionChecker, AIPermissionDenied
from app.ai.observability import AIObserver
from app.ai.memory.vector_memory import VectorMemory
import logging

logger = logging.getLogger(__name__)

# Tools that involve money (for amount limit checks)
FINANCIAL_TOOLS = {
    "create_invoice": lambda p: sum(i.get("quantity", 0) * i.get("unit_price", 0) for i in p.get("items", [])),
    "record_payment": lambda p: p.get("amount", 0),
    "refund_payment": lambda p: p.get("amount", 0),
    "apply_discount": lambda p: p.get("discount_amount", 0),
}


class ToolExecutor:
    """Pure execution layer. No LLM. No reasoning.
    Maps tool names to backend service functions and runs them.

    Safety stack (in order):
    1. Permission check (role-based)
    2. Amount limit check (role-based)
    3. Idempotency check (deduplication)
    4. Confirmation gate (dry-run for sensitive ops)
    5. Execute + audit log
    6. Record for idempotency + rollback + memory
    """

    def __init__(self, db: Session, session_id: str = "", user_role: str = "ai_agent"):
        self.db = db
        self.session_id = session_id
        self.user_role = user_role
        self._tools = None
        self.guard = TransactionGuard()
        self.idempotency = IdempotencyGuard(session_id)
        self.permissions = AIPermissionChecker(user_role)
        self.observer = AIObserver(session_id, user_role)
        self.vector_memory = VectorMemory()

    @property
    def tools(self):
        if self._tools is None:
            self._tools = self._build_tool_map()
        return self._tools

    def _build_tool_map(self) -> dict:
        from app.ai.tools.sales_tools import SalesTools
        from app.ai.tools.stock_tools import StockTools
        from app.ai.tools.finance_tools import FinanceTools
        from app.ai.tools.reporting_tools import ReportingTools
        from app.ai.tools.action_tools import ActionTools
        from app.ai.rag.retriever import ERPContextRetriever

        sales = SalesTools(self.db)
        stock = StockTools(self.db)
        finance = FinanceTools(self.db)
        reporting = ReportingTools(self.db)
        actions = ActionTools(self.db)
        retriever = ERPContextRetriever(self.db)

        return {
            # --- Read: Sales ---
            "get_today_sales": lambda **_: sales.get_today_sales(),
            "get_customer_info": lambda **p: sales.get_customer_info(p["customer_id"]),
            "get_customer_history": lambda **p: sales.get_customer_history(p["customer_id"], p.get("limit", 10)),
            "get_top_selling_products": lambda **p: sales.get_top_selling_products(p.get("limit", 10), p.get("by", "revenue")),
            "get_unpaid_invoices": lambda **p: sales.get_unpaid_invoices(p.get("customer_id")),
            # --- Read: Inventory ---
            "get_stock_level": lambda **p: stock.get_stock_level(p["product_id"], p.get("warehouse_id")),
            "get_low_stock_items": lambda **p: stock.get_low_stock_items(p.get("threshold", 10)),
            "get_stock_movement_history": lambda **p: stock.get_stock_movement_history(p["product_id"], p.get("limit", 20)),
            "get_warehouse_summary": lambda **p: stock.get_warehouse_summary(p["warehouse_id"]),
            "get_dead_stock": lambda **p: stock.get_dead_stock(p.get("days", 30)),
            "get_stock_valuation": lambda **p: stock.get_stock_valuation(p.get("warehouse_id")),
            # --- Read: Finance ---
            "get_profit_and_loss": lambda **p: finance.get_profit_and_loss(p["start_date"], p["end_date"]),
            "get_cash_balance": lambda **_: finance.get_cash_balance(),
            "get_receivables_summary": lambda **_: finance.get_receivables_summary(),
            "get_payables_summary": lambda **_: finance.get_payables_summary(),
            "get_expense_breakdown": lambda **p: finance.get_expense_breakdown(p["start_date"], p["end_date"]),
            "get_daily_revenue": lambda **p: finance.get_daily_revenue(p["start_date"], p["end_date"]),
            "demand_forecast": lambda **p: reporting.demand_forecast(p["product_id"], p.get("days_back", 30)),
            # --- Read: Search ---
            "search_products": lambda **p: retriever.search_products(p["query"]),
            "search_customers": lambda **p: retriever.search_customers(p["query"]),
            # --- Write: Sales ---
            "create_invoice": lambda **p: actions.create_invoice(
                customer_id=p.get("customer_id"),
                items=p["items"],
                payment_type=p.get("payment_type", "cash"),
                warehouse_id=p.get("warehouse_id", 1),
                discount=p.get("discount", 0),
                paid_amount=p.get("paid_amount"),
                notes=p.get("notes"),
            ),
            "cancel_invoice": lambda **p: actions.cancel_invoice(p["invoice_id"], p.get("reason")),
            "apply_discount": lambda **p: actions.apply_discount(p["invoice_id"], p["discount_amount"]),
            # --- Write: Payments ---
            "record_payment": lambda **p: actions.record_payment(
                customer_id=p["customer_id"],
                invoice_id=p["invoice_id"],
                amount=p["amount"],
                notes=p.get("notes"),
            ),
            "refund_payment": lambda **p: actions.refund_payment(p["invoice_id"], p["amount"], p.get("reason")),
            # --- Write: Inventory ---
            "update_stock": lambda **p: actions.update_stock(
                product_id=p["product_id"],
                warehouse_id=p["warehouse_id"],
                quantity=p["quantity"],
                cost_per_unit=p.get("cost_per_unit", 0),
                notes=p.get("notes"),
            ),
            "transfer_stock": lambda **p: actions.transfer_stock(
                product_id=p["product_id"],
                from_warehouse_id=p["from_warehouse_id"],
                to_warehouse_id=p["to_warehouse_id"],
                quantity=p["quantity"],
                notes=p.get("notes"),
            ),
            "adjust_stock": lambda **p: actions.adjust_stock(
                product_id=p["product_id"],
                warehouse_id=p["warehouse_id"],
                new_quantity=p["new_quantity"],
                reason=p.get("reason", "manual_adjustment"),
            ),
            # --- Write: CRM ---
            "create_customer": lambda **p: actions.create_customer(
                name=p["name"],
                phone=p.get("phone"),
                address=p.get("address"),
                credit_limit=p.get("credit_limit", 0),
                payment_terms=p.get("payment_terms", 0),
                notes=p.get("notes"),
            ),
            "update_customer": lambda **p: actions.update_customer(
                customer_id=p["customer_id"],
                name=p.get("name"),
                phone=p.get("phone"),
                address=p.get("address"),
                credit_limit=p.get("credit_limit"),
                payment_terms=p.get("payment_terms"),
                notes=p.get("notes"),
            ),
            # --- Safety: Confirmation ---
            "confirm_transaction": lambda **p: self._confirm_transaction(p["confirmation_id"]),
        }

    def execute(self, tool_name: str, tool_input: dict) -> str:
        """Execute a tool by name with full safety stack."""
        audit = self.observer.start(tool_name, tool_input)

        if tool_name == "confirm_transaction":
            result = self._confirm_transaction(tool_input.get("confirmation_id", ""))
            self.observer.complete(audit, json.loads(result))
            return result

        fn = self.tools.get(tool_name)
        if not fn:
            error_result = {"error": f"Unknown tool: {tool_name}"}
            self.observer.fail(audit, f"Unknown tool: {tool_name}")
            return json.dumps(error_result)

        # 1. Permission check
        try:
            self.permissions.check_or_raise(tool_name)
        except AIPermissionDenied as e:
            self.observer.block(audit, e.reason)
            return json.dumps({
                "error": "permission_denied",
                "message": e.reason,
                "role": self.user_role,
                "tool": tool_name,
            })

        # 2. Amount limit check
        if tool_name in FINANCIAL_TOOLS:
            amount = FINANCIAL_TOOLS[tool_name](tool_input)
            try:
                self.permissions.check_amount(tool_name, amount)
            except AIPermissionDenied as e:
                self.observer.block(audit, e.reason)
                return json.dumps({
                    "error": "amount_exceeded",
                    "message": e.reason,
                    "role": self.user_role,
                    "amount": amount,
                })

        # For write operations: apply remaining safety layers
        if tool_name in SENSITIVE_OPERATIONS:
            return self._execute_with_safety(tool_name, tool_input, fn, audit)

        # Read operations: execute directly
        try:
            result = fn(**tool_input)
            result_dict = result if isinstance(result, dict) else {"result": result}
            self.observer.complete(audit, result_dict)
            return json.dumps(result, default=str)
        except Exception as e:
            self.observer.fail(audit, str(e))
            logger.error(f"Tool execution error [{tool_name}]: {e}")
            return json.dumps({"error": str(e)})

    def _execute_with_safety(self, tool_name: str, params: dict, fn, audit) -> str:
        """Execute a write operation with idempotency + confirmation + rollback."""

        # 3. Idempotency check
        cached = self.idempotency.check_duplicate(tool_name, params)
        if cached:
            self.observer.complete(audit, cached)
            return json.dumps(cached, default=str)

        # 4. Confirmation check
        role_threshold = self.permissions.get_confirmation_threshold()
        needs_confirm = self.guard.needs_confirmation(tool_name, params)

        if tool_name in FINANCIAL_TOOLS:
            amount = FINANCIAL_TOOLS[tool_name](params)
            if amount > role_threshold:
                needs_confirm = True

        if needs_confirm:
            preview = self.guard.dry_run(tool_name, params)
            confirmation_id = self.guard.store_pending(self.session_id, tool_name, params)
            result = {
                "status": "requires_confirmation",
                "preview": preview,
                "confirmation_id": confirmation_id,
                "message": f"⚠️ هل تريد تنفيذ: {preview['would_do']}؟ قل 'أكد' أو 'تأكيد' للمتابعة.",
            }
            self.observer.complete(audit, result)
            return json.dumps(result, default=str)

        # 5. Execute
        try:
            result = fn(**params)
            result_dict = result if isinstance(result, dict) else {"result": result}

            # 6. Record
            self.idempotency.record_execution(tool_name, params, result_dict)
            rollback_id = self.guard.store_rollback_info(tool_name, params, result_dict)
            result_dict["_rollback_id"] = rollback_id

            self._store_in_memory(tool_name, params, result_dict)
            self.observer.complete(audit, result_dict)

            return json.dumps(result_dict, default=str)
        except Exception as e:
            self.observer.fail(audit, str(e))
            logger.error(f"Tool execution error [{tool_name}]: {e}")
            return json.dumps({"error": str(e)})

    def _confirm_transaction(self, confirmation_id: str) -> str:
        """Execute a previously stored pending transaction after user confirms."""
        if not confirmation_id:
            return json.dumps({"error": "كود التأكيد مطلوب"})

        tx = self.guard.confirm_and_clear(confirmation_id)
        if not tx:
            return json.dumps({"error": "العملية انتهت صلاحيتها أو غير موجودة. أعد الطلب."})

        tool_name = tx["tool_name"]
        params = tx["params"]
        fn = self.tools.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})

        try:
            result = fn(**params)
            result_dict = result if isinstance(result, dict) else {"result": result}

            self.idempotency.record_execution(tool_name, params, result_dict)
            rollback_id = self.guard.store_rollback_info(tool_name, params, result_dict)
            result_dict["_rollback_id"] = rollback_id
            result_dict["_confirmed"] = True

            self._store_in_memory(tool_name, params, result_dict)
            return json.dumps(result_dict, default=str)
        except Exception as e:
            logger.error(f"Confirmed tool execution error [{tool_name}]: {e}")
            return json.dumps({"error": str(e)})

    def _store_in_memory(self, tool_name: str, params: dict, result: dict):
        """Store transaction in vector memory for long-term recall."""
        try:
            if tool_name == "create_invoice":
                customer_id = params.get("customer_id") or result.get("customer_id", 0)
                self.vector_memory.store_transaction_fact(
                    customer_id=customer_id,
                    customer_name=result.get("customer_name", f"عميل #{customer_id}"),
                    action="فاتورة جديدة",
                    details={
                        "invoice_id": result.get("invoice_id") or result.get("id"),
                        "total": result.get("total", 0),
                        "items": params.get("items", []),
                    },
                )
            elif tool_name == "record_payment":
                self.vector_memory.store_transaction_fact(
                    customer_id=params.get("customer_id", 0),
                    customer_name=f"عميل #{params.get('customer_id', 0)}",
                    action="دفعة مسجلة",
                    details={"amount": params.get("amount", 0), "invoice_id": params.get("invoice_id")},
                )
            elif tool_name == "create_customer":
                name = params.get("name", "")
                customer_id = result.get("customer_id") or result.get("id", 0)
                phone = params.get("phone", "غير محدد")
                address = params.get("address", "غير محدد")
                self.vector_memory.store_customer_fact(
                    customer_id=customer_id,
                    name=name,
                    fact=f"عميل جديد. تليفون: {phone}. عنوان: {address}",
                )
        except Exception as e:
            logger.warning(f"Memory store failed (non-critical): {e}")
