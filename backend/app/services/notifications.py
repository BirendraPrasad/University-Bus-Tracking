def create_notification(cursor, user_id, title, message, notification_type="GENERAL"):
    cursor.execute("""
        INSERT INTO notifications
            (user_id, title, message, notification_type)
        VALUES (%s, %s, %s, %s)
        RETURNING notification_id
    """, (user_id, title, message, notification_type))

    return cursor.fetchone()[0]


DEFAULT_NOTIFICATION_PREFERENCES = {
    "busArrival": True,
    "routeUpdates": True,
    "timetableReminders": False,
    "tripAlerts": True,
    "gpsAlerts": True,
    "systemAlerts": True,
    "showRecentNotifications": True,
    "compactTables": False,
}


def create_notification_if_enabled(
    cursor, user_id, title, message,
    preference_key="systemAlerts",
    notification_type="GENERAL"
):
    """Create a notification only when the user's preference allows it."""
    import json

    cursor.execute("""
        SELECT preferences
        FROM user_notification_preferences
        WHERE user_id = %s
    """, (user_id,))
    row = cursor.fetchone()

    preferences = row[0] if row else {}
    if isinstance(preferences, str):
        preferences = json.loads(preferences)

    enabled = preferences.get(
        preference_key,
        DEFAULT_NOTIFICATION_PREFERENCES.get(preference_key, True)
    )

    if not enabled:
        return None

    return create_notification(
        cursor, user_id, title, message, notification_type
    )
