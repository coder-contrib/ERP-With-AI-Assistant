from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.opening_balance import (
    CustomerOpeningBalanceCreate,
    SupplierOpeningBalanceCreate,
    CashOpeningBalanceCreate,
)
from app.services.opening_balance_service import OpeningBalanceService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.post("/customer", status_code=201)
def create_customer_opening_balance(
    data: CustomerOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    service = OpeningBalanceService(db)
    try:
        result = service.set_customer_opening_balance(
            customer_id=data.customer_id,
            amount=data.amount,
            balance_type=data.balance_type,
            notes=data.notes,
        )
        db.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/supplier", status_code=201)
def create_supplier_opening_balance(
    data: SupplierOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    service = OpeningBalanceService(db)
    try:
        result = service.set_supplier_opening_balance(
            supplier_id=data.supplier_id,
            amount=data.amount,
            balance_type=data.balance_type,
            notes=data.notes,
        )
        db.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/cash", status_code=201)
def create_cash_opening_balance(
    data: CashOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    service = OpeningBalanceService(db)
    result = service.set_cash_opening_balance(
        amount=data.amount,
        account_name=data.account_name,
        notes=data.notes,
    )
    db.commit()
    return result


@router.get("")
def get_opening_balances(
    entity_type: str | None = None,
    current_user: User = Depends(require_permission("accounting:read")),
    db: Session = Depends(get_db),
):
    service = OpeningBalanceService(db)
    return service.get_opening_balances(entity_type)
