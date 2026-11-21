def create_notification(cursor, user_id, title, message, notification_type="GENERAL"):
    cursor.execute("""
        INSERT INTO notifications
            (user_id, title, message, notification_type)
        VALUES (%s, %s, %s, %s)
        RETURNING notification_id
    """, (user_id, title, message, notification_type))

    return cursor.fetchone()[0]
