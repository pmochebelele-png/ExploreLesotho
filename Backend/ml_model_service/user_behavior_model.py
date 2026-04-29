# ml_model/user_behavior_model.py

import numpy as np
from datetime import datetime


class UserBehaviorModel:
    def __init__(self):
        # Thresholds (you can tune these later)
        self.block_threshold = 60
        self.suspicious_threshold = 30

    # ============================================
    # 🔍 MAIN FRAUD ANALYSIS FUNCTION
    # ============================================
    def analyze(self, user):
        try:
            # ✅ Safe extraction (prevents crashes)
            bookings = user.get("bookings_made", 0)
            payments = user.get("payments_completed", 0)
            cancellations = user.get("cancellations", 0)
            failed_payments = user.get("failed_payments", 0)
            no_shows = user.get("no_shows", 0)
            login_frequency = user.get("login_frequency", 1)
            account_age_days = user.get("account_age_days", 1)

            fraud_score = 0
            reasons = []

            # ============================================
            # 🚨 RULE 1: BOOKINGS WITHOUT PAYMENTS
            # ============================================
            if bookings >= 5 and payments == 0:
                fraud_score += 40
                reasons.append("Multiple bookings without payment")

            # ============================================
            # 🚨 RULE 2: FAILED PAYMENTS
            # ============================================
            if failed_payments >= 3:
                fraud_score += 25
                reasons.append("Multiple failed payments")

            # ============================================
            # 🚨 RULE 3: HIGH CANCELLATION RATE
            # ============================================
            if bookings > 0:
                cancellation_rate = cancellations / bookings
                if cancellation_rate > 0.6:
                    fraud_score += 20
                    reasons.append("High cancellation rate")

            # ============================================
            # 🚨 RULE 4: NO SHOWS (VERY IMPORTANT FOR TOURISM)
            # ============================================
            if no_shows >= 2:
                fraud_score += 25
                reasons.append("Repeated no-shows (wasting vendor slots)")

            # ============================================
            # 🚨 RULE 5: BOT / SPAM BEHAVIOR
            # ============================================
            if login_frequency > 50:
                fraud_score += 15
                reasons.append("Unusual high activity (possible bot)")

            # ============================================
            # 🚨 RULE 6: NEW ACCOUNT ABUSE
            # ============================================
            if account_age_days < 3 and bookings > 3:
                fraud_score += 20
                reasons.append("New account making many bookings")

            # ============================================
            # 🚨 RULE 7: PAYMENT RATIO CHECK
            # ============================================
            if bookings > 0:
                payment_ratio = payments / bookings
                if payment_ratio < 0.3:
                    fraud_score += 20
                    reasons.append("Very low payment completion rate")

            # ============================================
            # 🎯 FINAL DECISION
            # ============================================
            if fraud_score >= self.block_threshold:
                status = "BLOCKED ❌"
                action = "User should be prevented from making bookings"
            elif fraud_score >= self.suspicious_threshold:
                status = "SUSPICIOUS ⚠️"
                action = "Require verification (OTP / payment upfront)"
            else:
                status = "TRUSTED ✅"
                action = "Allow normal access"

            return {
                "status": status,
                "fraud_score": fraud_score,
                "reasons": reasons if reasons else ["Normal user behavior"],
                "recommended_action": action,
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }

        except Exception as e:
            return {
                "status": "ERROR",
                "error": str(e)
            }