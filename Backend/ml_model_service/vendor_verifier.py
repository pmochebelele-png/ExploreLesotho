# ml_model/vendor_verifier.py

import joblib
from datetime import datetime


class VendorVerifier:
    def __init__(self, model_path="models/vendor_model.pkl"):
        """Load trained model, falling back safely when artifacts are incompatible."""
        self.model = None
        self.scaler = None
        self.encoders = {}
        self._load_error = None

        candidate_paths = [
            model_path,
            "models/vendor_model.pkl",
            "models/vendor_classifier.pkl",
        ]

        for candidate in dict.fromkeys(candidate_paths):
            try:
                data = joblib.load(candidate)
                self.model = data.get("model")
                self.scaler = data.get("scaler")
                self.encoders = data.get("label_encoders", {})
                self._load_error = None
                break
            except Exception as error:
                self._load_error = str(error)

    # ============================================
    # 🔍 VERIFY VENDOR (MAIN FUNCTION)
    # ============================================
    def verify(self, vendor):
        try:
            if not self.model or not self.scaler or not self.encoders:
                return self._heuristic_verify(vendor)

            # Encode categorical values
            bt = self._safe_transform(
                self.encoders.get('business_type'),
                vendor.get('business_type'),
            )
            dist = self._safe_transform(
                self.encoders.get('district'),
                vendor.get('district'),
            )

            # Feature vector
            X = [[
                bt,
                dist,
                1 if vendor.get('has_license') else 0,
                1 if vendor.get('license_valid') else 0,
                1 if vendor.get('tax_clearance') else 0,
                float(vendor.get('previous_experience', 0) or 0),
                float(vendor.get('rating', 0) or 0),
            ]]

            # Scale
            X = self.scaler.transform(X)

            # Predict
            prediction = self.model.predict(X)[0]
            prob = self.model.predict_proba(X)[0]

            # Decision reasoning
            reasons = self._get_reasons(vendor, prediction)

            return {
                "approved": bool(prediction),
                "confidence": float(max(prob)),
                "approval_probability": float(prob[1]),
                "rejection_probability": float(prob[0]),
                "reasons": reasons
            }

        except Exception as e:
            return self._heuristic_verify(vendor, error=str(e))

    def _safe_transform(self, encoder, value):
        if encoder is None or not hasattr(encoder, "classes_"):
            return 0

        text = str(value or "").strip()
        if text in encoder.classes_:
            return encoder.transform([text])[0]
        return 0

    def _heuristic_verify(self, vendor, error=None):
        reasons = self._get_reasons(vendor, approved=True)
        score = 0

        if vendor.get('has_license'):
            score += 35
        if vendor.get('license_valid'):
            score += 25
        if vendor.get('tax_clearance'):
            score += 15

        experience = float(vendor.get('previous_experience', 0) or 0)
        rating = float(vendor.get('rating', 0) or 0)

        score += min(experience * 5, 15)
        score += min(max(rating, 0) * 2, 10)

        approved = score >= 60 and not any(
            token in " ".join(reasons).lower()
            for token in ["missing business license", "license is invalid", "no tax clearance"]
        )

        result = {
            "approved": approved,
            "confidence": round(min(max(score / 100, 0.45), 0.95), 2),
            "approval_probability": round(min(score / 100, 0.95), 2),
            "rejection_probability": round(1 - min(score / 100, 0.95), 2),
            "reasons": reasons if reasons else ["Heuristic fallback accepted vendor"],
            "mode": "heuristic_fallback",
        }
        if error or self._load_error:
            result["warning"] = error or self._load_error
        return result

    # ============================================
    # 🧠 DECISION REASONS (VERY IMPORTANT)
    # ============================================
    def _get_reasons(self, vendor, approved):
        reasons = []

        if not vendor.get('has_license'):
            reasons.append("❌ Missing business license")

        if not vendor.get('license_valid'):
            reasons.append("❌ License is invalid or expired")

        if not vendor.get('tax_clearance'):
            reasons.append("❌ No tax clearance")

        if vendor.get('previous_experience', 0) < 2:
            reasons.append("❌ Insufficient experience (< 2 years)")

        if vendor.get('rating', 0) < 3:
            reasons.append("❌ Low rating")

        if approved:
            if len(reasons) == 0:
                return ["✅ All requirements satisfied"]
            else:
                return ["⚠️ Approved but with minor issues"] + reasons

        return reasons

    # ============================================
    # 🚀 AUTOMATION HOOK (FOR YOUR SYSTEM)
    # ============================================
    def auto_verify_and_notify(self, vendor):
        """
        This is what your system should call when a vendor registers
        """
        result = self.verify(vendor)

        if result.get("error"):
            return result

        if result["approved"]:
            status = "APPROVED ✅"
        else:
            status = "REJECTED ❌"

        # 🔔 ADMIN NOTIFICATION MESSAGE
        notification = {
            "vendor_name": vendor.get("name", "Unknown"),
            "status": status,
            "confidence": result["confidence"],
            "reasons": result["reasons"],
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        # 👉 Here you can connect:
        # - Email system
        # - Admin dashboard
        # - Database logging

        print("\n🔔 ADMIN ALERT:")
        print(notification)

        return {
            "decision": result,
            "admin_notification": notification
        }
