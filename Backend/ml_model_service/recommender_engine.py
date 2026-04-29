# ml_model/recommender_engine.py

import joblib
import pandas as pd
from sklearn.preprocessing import LabelEncoder


class RecommenderEngine:
    def __init__(
        self,
        model_path="models/recommender.pkl",
        data_path="data/culture_combined.csv",
    ):
        self.model_path = model_path
        self.data_path = data_path
        self.model = None
        self.encoder = LabelEncoder()
        self.data = pd.DataFrame()
        self.load_error = None
        self.load()

    def load(self):
        try:
            bundle = joblib.load(self.model_path)
            if isinstance(bundle, dict):
                self.model = bundle.get("model")
                self.encoder = bundle.get("encoder", self.encoder)
                self.data = bundle.get("data", pd.DataFrame())
            else:
                self.model = bundle
        except Exception as error:
            self.load_error = str(error)
            self.model = None

        if self.data.empty:
            self.data = pd.read_csv(self.data_path)

        self.data = self.data.fillna("")
        self.data["location"] = (
            self.data["location"].astype(str).str.strip().str.lower().replace(
                {"unknown": "maseru", "": "maseru", "ty": "maseru"}
            )
        ).str.title()

        if not hasattr(self.encoder, "classes_"):
            self.encoder.fit(self.data["location"])

        return self

    def _records(self, frame):
        columns = [
            column
            for column in [
                "name_and_surname",
                "business_name",
                "product_range",
                "category",
                "contacts",
                "location",
                "score",
            ]
            if column in frame.columns
        ]
        return frame[columns].to_dict(orient="records")

    def recommend(self, location="Maseru", limit=5):
        limit = max(1, min(int(limit or 5), 20))
        normalized_location = str(location or "Maseru").strip().title()

        candidates = self.data.copy()
        if normalized_location in set(candidates["location"]):
            candidates = candidates[candidates["location"] == normalized_location].copy()

        if self.model is not None:
            encoded_locations = self.encoder.transform(candidates["location"])
            candidates["score"] = self.model.predict(
                pd.DataFrame({"loc_encoded": encoded_locations})
            )
        else:
            candidates["score"] = 75.0
            if "category" in candidates.columns:
                category_weight = (
                    candidates["category"].astype(str).map(
                        candidates["category"].astype(str).value_counts()
                    )
                ).fillna(1)
                candidates["score"] = candidates["score"] + category_weight

        ranked = candidates.sort_values("score", ascending=False).head(limit)
        return self._records(ranked)
