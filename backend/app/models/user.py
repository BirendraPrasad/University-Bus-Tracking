from dataclasses import dataclass
from typing import Optional


@dataclass
class User:
    user_id: Optional[int]
    name: str
    email: str
    password_hash: str
    role: str
    is_active: bool = True