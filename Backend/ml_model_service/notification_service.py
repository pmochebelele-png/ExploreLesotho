# notification_service.py

def notify_admin(vendor_name, result):
    if not result["approved"]:
        print(f"\n🚨 ALERT: Vendor '{vendor_name}' REJECTED")
        print("Reason(s):")
        for r in result["reasons"]:
            print(f" - {r}")
    else:
        print(f"\n✅ Vendor '{vendor_name}' APPROVED")
    return result

# Add this class for compatibility with flask_api.py
class NotificationService:
    def __init__(self):
        print("✅ Notification Service initialized")
    
    def send_admin_alert(self, subject, message):
        print(f"\n🔔 ADMIN ALERT: {subject}")
        print(f"   {message}")
        return True
    
    def send_vendor_notification(self, email, status, reason):
        print(f"\n📧 Vendor Notification: {email}")
        print(f"   Status: {status}")
        print(f"   Reason: {reason}")
        return True