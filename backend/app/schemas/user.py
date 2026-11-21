from pydantic import BaseModel, EmailStr
from typing import Literal


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: Literal["STUDENT", "DRIVER", "FACULTY", "ADMIN"]




class StudentCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    enrollment_no: str
    department: str
    semester: int    

class DriverCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    license_number: str
    phone: str   

class FacultyCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    employee_id: str
    department: str    

class BusCreate(BaseModel):
    bus_number: str
    bus_type: Literal["ROUTE_BUS", "SHUTTLE_BUS"]
    capacity: int
    registration_number: str
    route_id: int | None = None

class BusUpdate(BaseModel):
    bus_number: str | None = None
    bus_type: Literal["ROUTE_BUS", "SHUTTLE_BUS"] | None = None
    capacity: int | None = None
    registration_number: str | None = None
    route_id: int | None = None
    
class RouteCreate(BaseModel):
    route_name: str
    route_code: str
    description: str
    start_point: str
    end_point: str   

class StopCreate(BaseModel):
    route_id: int
    stop_name: str
    latitude: float
    longitude: float
    stop_order: int
    pickup_time: str | None = None
    drop_time: str | None = None


class RouteUpdate(BaseModel):
    route_name: str | None = None
    route_code: str | None = None
    description: str | None = None
    start_point: str | None = None
    end_point: str | None = None
    is_active: bool | None = None


class StopUpdate(BaseModel):
    stop_name: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    stop_order: int | None = None
    pickup_time: str | None = None
    drop_time: str | None = None

class BusAssignDriver(BaseModel):
    driver_id: int


# register
class UserLogin(BaseModel):
    email: str
    password: str
    route_id: int | None = None


class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: Literal["STUDENT", "FACULTY", "DRIVER", "ADMIN"]

    # Student details
    enrollment_no: str | None = None
    department: str | None = None
    semester: int | None = None

    # Faculty details
    employee_id: str | None = None 

    # Driver details
    license_number: str | None = None
    phone: str | None = None