from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import date
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.ai.anomaly_detector import AnomalyDetector

router = APIRouter()


@router.get("/scan")
def scan_anomalies(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return {"anomalies": detector.scan_all_anomalies()}


@router.get("/revenue")
def revenue_anomaly(target_date: date = Query(default=None), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return detector.detect_revenue_anomaly(target_date)


@router.get("/expenses")
def expense_anomaly(target_date: date = Query(default=None), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return detector.detect_expense_anomaly(target_date)


@router.get("/profit")
def profit_anomaly(target_date: date = Query(default=None), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return detector.detect_profit_anomaly(target_date)


@router.get("/rolling-baseline")
def rolling_baseline(days: int = Query(default=7), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return detector.revenue_vs_rolling_baseline(days)


@router.get("/seasonal")
def seasonal_baseline(target_date: date = Query(default=None), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    detector = AnomalyDetector(db)
    return detector.seasonal_baseline(target_date)
