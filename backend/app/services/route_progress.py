"""Helpers for deriving live route progress from stop events and GPS."""
from math import radians, sin, cos, asin, sqrt


def _distance_m(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = map(
        radians, (float(lat1), float(lon1), float(lat2), float(lon2))
    )
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 6371000 * 2 * asin(sqrt(a))


def _same_stop_location(a, b):
    """Identify duplicate consecutive entries for the same physical stop."""
    name_a = (a[1] or "").strip().casefold()
    name_b = (b[1] or "").strip().casefold()

    if not name_a or name_a != name_b:
        return False

    if any(value is None for value in (a[4], a[5], b[4], b[5])):
        return False

    try:
        return _distance_m(a[4], a[5], b[4], b[5]) <= 30
    except (TypeError, ValueError):
        return False


def _next_distinct_stop(stops, current):
    """Find the next unvisited physical stop, skipping duplicate entries."""
    for row in stops:
        if row[6] <= current[6] or row[2] is not None:
            continue
        if _same_stop_location(current, row):
            continue
        return row
    return None


def get_route_progress(cursor, trip_id, route_id,
                       latitude=None, longitude=None, speed_mps=None):
    """Return sequential stop progress and conservative ETA."""
    cursor.execute("""
        SELECT s.stop_id, s.stop_name, e.arrival_time, e.departure_time,
               s.latitude, s.longitude, s.stop_order
        FROM stops s
        LEFT JOIN trip_stop_events e
          ON e.trip_id = %s AND e.stop_id = s.stop_id
        WHERE s.route_id = %s
        ORDER BY s.stop_order
    """, (trip_id, route_id))

    stops = cursor.fetchall()

    current = None
    next_stop = None

    # Prefer actual arrival/departure events when available.
    for row in stops:
        if row[2] is not None and row[3] is None:
            current = row
            break

    if current is not None:
        next_stop = _next_distinct_stop(stops, current)

    # Without stop events, estimate the upcoming stop from GPS.
    elif latitude is not None and longitude is not None:
        try:
            valid_stops = [
                row for row in stops
                if row[4] is not None and row[5] is not None
                and -90 <= float(row[4]) <= 90
                and -180 <= float(row[5]) <= 180
                and not (float(row[4]) == 0 and float(row[5]) == 0)
                and row[2] is None
            ]

            if valid_stops:
                nearest = min(
                    valid_stops,
                    key=lambda row: _distance_m(
                        latitude, longitude, row[4], row[5]
                    )
                )

                distance_to_nearest = _distance_m(
                    latitude, longitude, nearest[4], nearest[5]
                )

                if distance_to_nearest > 100:
                    # Bus is approaching this stop: previous stop is current.
                    previous = [
                        row for row in stops
                        if row[6] < nearest[6]
                    ]
                    current = previous[-1] if previous else None
                    next_stop = nearest
                else:
                    # Bus is at this stop; find the next distinct stop.
                    current = nearest
                    next_stop = _next_distinct_stop(stops, current)

        except (TypeError, ValueError):
            pass

    else:
        # No GPS yet: report the first unvisited stop as upcoming.
        next_stop = next(
            (row for row in stops if row[2] is None),
            None
        )

    distance = None
    eta = None

    if next_stop and latitude is not None and longitude is not None:
        try:
            slat, slng = float(next_stop[4]), float(next_stop[5])
            if (-90 <= slat <= 90 and -180 <= slng <= 180
                    and not (slat == 0 and slng == 0)):
                distance = round(
                    _distance_m(latitude, longitude, slat, slng)
                )
                speed = float(speed_mps) if speed_mps is not None else 0
                if speed > 1.0:
                    eta = max(1, round(distance / speed / 60))
        except (TypeError, ValueError):
            pass

    return {
        "current_stop": current[1] if current else None,
        "next_stop": next_stop[1] if next_stop else None,
        "distance_to_next_stop_m": distance,
        "eta_minutes": eta,
    }
