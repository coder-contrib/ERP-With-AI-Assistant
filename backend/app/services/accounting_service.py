from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import date


class AccountingService:
    def __init__(self, db: Session):
        self.db = db

    def refresh_daily_summary(self, summary_date: date | None = None):
        if summary_date:
            self.db.execute(
                text("SELECT fn_refresh_daily_financial_summary(:d)"),
                {"d": summary_date},
            )
        else:
            self.db.execute(text("SELECT fn_refresh_daily_financial_summary()"))
        self.db.commit()

    def refresh_summary_range(self, start_date: date, end_date: date | None = None):
        if end_date:
            self.db.execute(
                text("SELECT fn_refresh_financial_summary_range(:s, :e)"),
                {"s": start_date, "e": end_date},
            )
        else:
            self.db.execute(
                text("SELECT fn_refresh_financial_summary_range(:s)"),
                {"s": start_date},
            )
        self.db.commit()
