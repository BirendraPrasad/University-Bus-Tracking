-- Campus geofence configuration
CREATE TABLE IF NOT EXISTS bus_geofence_state (
    bus_id INTEGER PRIMARY KEY REFERENCES buses(bus_id) ON DELETE CASCADE,
    is_inside BOOLEAN NOT NULL,
    last_latitude DECIMAL(10,7) NOT NULL,
    last_longitude DECIMAL(10,7) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bus_geofence_updated
ON bus_geofence_state(updated_at);
