from pydantic import BaseModel, EmailStr
from typing import Literal


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: Literal["STUDENT", "DRIVER", "FACULTY", "ADMIN"]


class UserLogin(BaseModel):
    email: EmailStr
    password: str

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

class BusAssignDriver(BaseModel):
    driver_id: int