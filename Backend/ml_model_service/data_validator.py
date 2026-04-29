# ml_model/data_validator.py

class DataValidator:

    def validate(self, row):
        issues = []

        if not row.get("name_and_surname"):
            issues.append("Missing name")

        if not row.get("location"):
            issues.append("Missing location")

        if row.get("location") == "Unknown":
            issues.append("Unclean location")

        return issues