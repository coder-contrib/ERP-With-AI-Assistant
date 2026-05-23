from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.services.insights_service import InsightsService

router = APIRouter()


@router.get("/")
def get_all_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return {"insights": service.get_all_insights()}


@router.get("/why-profit-dropped")
def why_profit_dropped(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return service.why_profit_dropped()


@router.get("/top-risks")
def top_risks(limit: int = 3, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return {"risks": service.top_risks(limit)}


@router.get("/profit-analysis")
def profit_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return {"insights": service.profit_analysis()}


@router.get("/risks")
def risk_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return {"insights": service.risk_analysis()}


@router.get("/opportunities")
def opportunity_insights(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = InsightsService(db)
    return {"insights": service.opportunity_analysis()}
