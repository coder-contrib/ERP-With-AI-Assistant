from enum import Enum


class Role(str, Enum):
    ADMIN = "admin"
    CASHIER = "cashier"
    ACCOUNTANT = "accountant"
    WAREHOUSE_EMPLOYEE = "warehouse_employee"


ROLE_PERMISSIONS = {
    Role.ADMIN: [
        "products:read", "products:write", "products:delete",
        "categories:read", "categories:write", "categories:delete",
        "inventory:read", "inventory:write", "inventory:transfer",
        "sales:read", "sales:write", "sales:return",
        "purchases:read", "purchases:write", "purchases:return",
        "customers:read", "customers:write", "customers:delete",
        "suppliers:read", "suppliers:write", "suppliers:delete",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "accounting:read", "accounting:write",
        "reports:read", "reports:export",
        "users:read", "users:write", "users:delete",
        "settings:read", "settings:write",
    ],
    Role.CASHIER: [
        "products:read",
        "categories:read",
        "inventory:read",
        "sales:read", "sales:write", "sales:return",
        "customers:read", "customers:write",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
    ],
    Role.ACCOUNTANT: [
        "products:read",
        "categories:read",
        "inventory:read",
        "sales:read",
        "purchases:read",
        "customers:read",
        "suppliers:read",
        "payments:read", "payments:write",
        "expenses:read", "expenses:write",
        "accounting:read", "accounting:write",
        "reports:read", "reports:export",
    ],
    Role.WAREHOUSE_EMPLOYEE: [
        "products:read",
        "categories:read",
        "inventory:read", "inventory:write", "inventory:transfer",
        "purchases:read",
    ],
}


def has_permission(role: str, permission: str) -> bool:
    try:
        role_enum = Role(role)
    except ValueError:
        return False
    return permission in ROLE_PERMISSIONS.get(role_enum, [])
