-- ============================================
-- UNIVERSITY BUS TRACKING SYSTEM
-- PostgreSQL Database Schema
-- ============================================

-- 1. USERS
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('STUDENT', 'DRIVER', 'FACULTY', 'ADMIN')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);


-- 2. STUDENTS
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    enrollment_no VARCHAR(50) UNIQUE NOT NULL,
    department VARCHAR(100),
    semester INTEGER,

    CONSTRAINT fk_student_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);


-- 3. DRIVERS
CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    phone VARCHAR(20),

    CONSTRAINT fk_driver_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);


-- 4. FACULTY
CREATE TABLE faculty (
    faculty_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    department VARCHAR(100),

    CONSTRAINT fk_faculty_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);


-- 5. BUSES
CREATE TABLE buses (
    bus_id SERIAL PRIMARY KEY,
    bus_number VARCHAR(50) UNIQUE NOT NULL,
    bus_type VARCHAR(20) NOT NULL
        CHECK (bus_type IN ('ROUTE_BUS', 'SHUTTLE_BUS')),
    capacity INTEGER,
    registration_number VARCHAR(50) UNIQUE,
    driver_id INTEGER,

    CONSTRAINT fk_bus_driver
        FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE SET NULL
);


-- 6. ROUTES
CREATE TABLE routes (
    route_id SERIAL PRIMARY KEY,
    route_name VARCHAR(100) NOT NULL,
    route_code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    start_point VARCHAR(150),
    end_point VARCHAR(150),
    is_active BOOLEAN DEFAULT TRUE
);


-- 7. STOPS
CREATE TABLE stops (
    stop_id SERIAL PRIMARY KEY,
    route_id INTEGER NOT NULL,
    stop_name VARCHAR(150) NOT NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    stop_order INTEGER NOT NULL,

    CONSTRAINT fk_stop_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id)
        ON DELETE CASCADE,

    CONSTRAINT unique_route_stop_order
        UNIQUE (route_id, stop_order)
);


-- 8. TRIPS
CREATE TABLE trips (
    trip_id SERIAL PRIMARY KEY,
    bus_id INTEGER NOT NULL,
    route_id INTEGER NOT NULL,
    driver_id INTEGER,
    trip_date DATE DEFAULT CURRENT_DATE,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'ACTIVE', 'COMPLETED', 'CANCELLED')),

    CONSTRAINT fk_trip_bus
        FOREIGN KEY (bus_id)
        REFERENCES buses(bus_id),

    CONSTRAINT fk_trip_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id),

    CONSTRAINT fk_trip_driver
        FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE SET NULL
);


-- 9. BUS LOCATIONS
CREATE TABLE bus_locations (
    location_id BIGSERIAL PRIMARY KEY,
    trip_id INTEGER NOT NULL,
    bus_id INTEGER NOT NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    speed DECIMAL(6, 2),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_location_trip
        FOREIGN KEY (trip_id)
        REFERENCES trips(trip_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_location_bus
        FOREIGN KEY (bus_id)
        REFERENCES buses(bus_id)
        ON DELETE CASCADE
);


-- 10. SUBSCRIPTIONS
CREATE TABLE subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL,
    route_id INTEGER NOT NULL,
    subscribed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_subscription_student
        FOREIGN KEY (student_id)
        REFERENCES students(student_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_subscription_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id)
        ON DELETE CASCADE,

    CONSTRAINT unique_student_route
        UNIQUE (student_id, route_id)
);


-- 11. SCHEDULES
CREATE TABLE schedules (
    schedule_id SERIAL PRIMARY KEY,
    route_id INTEGER NOT NULL,
    bus_id INTEGER,
    departure_time TIME NOT NULL,
    arrival_time TIME,
    day_of_week VARCHAR(20) NOT NULL,

    CONSTRAINT fk_schedule_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_schedule_bus
        FOREIGN KEY (bus_id)
        REFERENCES buses(bus_id)
        ON DELETE SET NULL
);


-- 12. NOTIFICATIONS
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);