-- Stop arrival and departure tracking
-- Existing trips and stops data remains unchanged.

CREATE TABLE IF NOT EXISTS trip_stop_events (
    event_id BIGSERIAL PRIMARY KEY,

    trip_id INTEGER NOT NULL
        REFERENCES trips(trip_id) ON DELETE CASCADE,

    stop_id INTEGER NOT NULL
        REFERENCES stops(stop_id) ON DELETE CASCADE,

    arrival_time TIMESTAMP WITHOUT TIME ZONE,
    departure_time TIMESTAMP WITHOUT TIME ZONE,

    created_at TIMESTAMP WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_trip_stop_event
        UNIQUE (trip_id, stop_id),

    CONSTRAINT valid_stop_event_times
        CHECK (
            departure_time IS NULL
            OR (
                arrival_time IS NOT NULL
                AND departure_time >= arrival_time
            )
        )
);

CREATE INDEX IF NOT EXISTS idx_trip_stop_events_trip
    ON trip_stop_events(trip_id);

CREATE INDEX IF NOT EXISTS idx_trip_stop_events_stop
    ON trip_stop_events(stop_id);
