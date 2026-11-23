def complete_stale_gps_trips():
    """
    GPS timeout must not complete an active trip.
    Only confirmed campus ENTRY completes a trip.
    """
    return 0
