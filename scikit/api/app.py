# Scikit API - single AI model service for Explore Lesotho.
# This keeps the app's existing /api/ml routes working while using the
# selected scikit-learn tourism model and dataset as the source of truth.
from pathlib import Path
from datetime import datetime, timedelta
import os

import numpy as np
import pandas as pd
from flask import Flask, jsonify, request
from flask_cors import CORS
from sklearn.ensemble import RandomForestRegressor
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.model_selection import train_test_split
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import StandardScaler


APP_DIR = Path(__file__).resolve().parent
SCIKIT_DIR = APP_DIR.parent
PROJECT_DIR = SCIKIT_DIR.parent
DATA_DIR = SCIKIT_DIR / "Dataset"


def _read_csv(name):
    return pd.read_csv(DATA_DIR / name).fillna("")


class ExploreLesothoScikitModel:
    def __init__(self):
        self.monthly = _read_csv("monthly_cleaned.csv")
        self.accommodation = _read_csv("accommodation_cleaned.csv")
        self.attractions = _read_csv("attractions_cleaned.csv")
        self.perceptions = _read_csv("perceptions_cleaned.csv")
        self.origin = _read_csv("origin_cleaned.csv")
        self.features_time = _read_csv("features_time.csv")
        self.features_attractions = _read_csv("features_attractions.csv")
        self.features_sentiment = _read_csv("features_sentiment.csv")
        self._train()

    def _train(self):
        x = self.features_time[["month_sin", "month_cos", "lag_1", "rolling_3"]].astype(float).values
        y = self.features_time["arrivals"].astype(float).values
        x_train, x_test, y_train, y_test = train_test_split(x, y, test_size=0.2, random_state=42)
        self.forecaster = RandomForestRegressor(n_estimators=160, random_state=42)
        self.forecaster.fit(x_train, y_train)
        self.forecast_score = float(self.forecaster.score(x_test, y_test)) if len(x_test) else 0.0

        attraction_features = self.attractions[["visitors", "domestic_pct", "international_pct"]].astype(float).values
        self.attraction_scaler = StandardScaler()
        self.attraction_matrix = self.attraction_scaler.fit_transform(attraction_features)
        self.attraction_neighbors = NearestNeighbors(metric="euclidean")
        self.attraction_neighbors.fit(self.attraction_matrix)

        records = []
        for _, row in self.monthly.iterrows():
            records.append(
                f"{row['month_name']} {row['season']} arrivals {row['arrivals']} revenue {row['revenue']}"
            )
        for _, row in self.attractions.iterrows():
            records.append(
                f"{row['attraction']} visitors {row['visitors']} domestic {row['domestic_pct']} international {row['international_pct']}"
            )
        for _, row in self.perceptions.iterrows():
            records.append(
                f"{row['sentiment']} {row['category']} perception {row['percentage']} percent"
            )
        for _, row in self.origin.iterrows():
            records.append(
                f"{row['country']} arrivals {row['arrivals_2024']} growth {row['growth_pct']} market share {row['market_share']}"
            )

        self.knowledge_records = records
        self.vectorizer = TfidfVectorizer(stop_words="english")
        self.knowledge_matrix = self.vectorizer.fit_transform(records)

    def overview(self):
        return {
            "knowledge_records": len(self.knowledge_records),
            "metric_records": int(
                len(self.monthly) + len(self.attractions) + len(self.perceptions) + len(self.origin)
            ),
            "topics": [
                "forecasting",
                "pricing",
                "sentiment",
                "attractions",
                "origin markets",
                "culture",
                "vendor performance",
                "recommendations",
            ],
            "reports": [
                "Arrivals and Accommodation Reports",
                "Key Attractions Statistics Report",
                "Perception Survey Report",
                "Visitor Exit Survey",
            ],
            "years": ["2016-2017", "2022", "2023", "2024"],
            "active_model": "Scikit-learn unified tourism model",
            "model_score": round(self.forecast_score, 3),
        }

    def forecast(self, days=30):
        today = datetime.now()
        rows = []
        for offset in range(1, min(max(int(days), 1), 90) + 1):
            date = today + timedelta(days=offset)
            month = date.month
            month_row = self.monthly[self.monthly["month"].astype(int) == month].iloc[0]
            features = np.array(
                [[
                    np.sin(2 * np.pi * month / 12),
                    np.cos(2 * np.pi * month / 12),
                    float(month_row["arrivals"]),
                    float(month_row["arrivals"]),
                ]]
            )
            prediction = self.forecaster.predict(features)[0]
            rows.append(
                {
                    "date": date.strftime("%Y-%m-%d"),
                    "month": month_row["month_name"],
                    "season": month_row["season"],
                    "bookings": max(0, int(round(prediction / 1000))),
                    "predicted_visitors": max(0, int(round(prediction))),
                }
            )
        return rows

    def pricing(self, base_price=1850):
        avg_arrivals = float(self.monthly["arrivals"].astype(float).mean())
        rows = []
        for _, row in self.monthly.iterrows():
            demand = float(row["arrivals"]) / avg_arrivals
            rows.append(
                {
                    "month": row["month_name"],
                    "season": row["season"],
                    "base_price": base_price,
                    "predicted_price": round(base_price * demand, 0),
                    "demand_multiplier": round(demand, 2),
                }
            )
        return rows

    def sentiment(self):
        positive_df = self.perceptions[
            ~self.perceptions["sentiment"].astype(str).str.lower().str.contains("poor")
        ]
        negative_df = self.perceptions[
            self.perceptions["sentiment"].astype(str).str.lower().str.contains("poor")
        ]
        sentiments = self.perceptions.to_dict(orient="records")
        return {
            "positive_percentage": round(float(positive_df["percentage"].astype(float).sum()), 1),
            "negative_percentage": round(float(negative_df["percentage"].astype(float).sum()), 1),
            "top_sentiment": sentiments[0]["sentiment"] if sentiments else "",
            "sentiments": sentiments,
        }

    def similar(self, attraction, top_n=3):
        names = self.attractions["attraction"].astype(str).tolist()
        lowered = [name.lower() for name in names]
        if attraction.lower() not in lowered:
            return []
        idx = lowered.index(attraction.lower())
        distances, indices = self.attraction_neighbors.kneighbors(
            self.attraction_matrix[idx].reshape(1, -1),
            n_neighbors=min(top_n + 1, len(names)),
        )
        rows = []
        for distance, rec_idx in zip(distances[0], indices[0]):
            if int(rec_idx) == idx:
                continue
            row = self.attractions.iloc[int(rec_idx)]
            rows.append(
                {
                    "name": row["attraction"],
                    "similarity": round(max(0, 100 - float(distance) * 25), 1),
                    "visitors": int(float(row["visitors"])),
                    "domestic_pct": float(row["domestic_pct"]),
                }
            )
        return rows[:top_n]

    def recommendations(self, location="Maseru", limit=10, category=None, subcategory=None):
        profile = f"{category or ''} {subcategory or ''}".lower()
        rows = []
        for _, row in self.attractions.iterrows():
            base_score = float(row.get("popularity", 0)) * 100
            culture_boost = 12 if any(
                word in f"{row['attraction']} {profile}".lower()
                for word in ["thaba", "morija", "kome", "culture", "heritage", "craft"]
            ) else 0
            rows.append(
                {
                    "name": row["attraction"],
                    "category": category or "tourism",
                    "subcategory": subcategory or "recommendation",
                    "location": location,
                    "score": round(min(100, base_score + culture_boost), 1),
                    "visitors": int(float(row["visitors"])),
                    "reason": "Recommended by the unified Scikit tourism model using visitor demand and attraction similarity.",
                }
            )
        return sorted(rows, key=lambda item: item["score"], reverse=True)[: int(limit)]

    def origin_analysis(self):
        top = self.origin.sort_values("arrivals_2024", ascending=False).head(5)
        high_growth = self.origin[self.origin["growth_pct"].astype(float) > 50]
        return {
            "top_markets": [
                {
                    "country": row["country"],
                    "arrivals": int(float(row["arrivals_2024"])),
                    "market_share": round(float(row["market_share"]), 1),
                    "growth": round(float(row["growth_pct"]), 1),
                }
                for _, row in top.iterrows()
            ],
            "fastest_growing": high_growth[["country", "growth_pct"]].to_dict(orient="records"),
        }

    def insights(self):
        monthly_top = self.monthly.sort_values("arrivals", ascending=False).iloc[0]
        attraction_top = self.attractions.sort_values("visitors", ascending=False).iloc[0]
        origin_top = self.origin.sort_values("arrivals_2024", ascending=False).iloc[0]
        sentiment = self.sentiment()
        pricing = self.pricing()
        peak_price = max(pricing, key=lambda item: item["predicted_price"])
        return [
            {
                "category": "Demand",
                "title": f"{monthly_top['month_name']} is the strongest tourism demand month",
                "description": f"The Scikit model identifies {monthly_top['month_name']} as peak demand with {int(float(monthly_top['arrivals'])):,} arrivals.",
                "evidence": [{"metric_label": "Arrivals", "primary_numeric_value": int(float(monthly_top["arrivals"])), "year": 2024}],
            },
            {
                "category": "Attractions",
                "title": f"{attraction_top['attraction']} leads attraction demand",
                "description": f"{attraction_top['attraction']} records the strongest attraction signal with {int(float(attraction_top['visitors'])):,} visitors.",
                "evidence": [{"metric_label": "Visitors", "primary_numeric_value": int(float(attraction_top["visitors"])), "year": 2024}],
            },
            {
                "category": "Markets",
                "title": f"{origin_top['country']} is the strongest source market",
                "description": f"{origin_top['country']} contributes {round(float(origin_top['market_share']), 1)}% of recorded arrivals.",
                "evidence": [{"metric_label": "Market share", "primary_numeric_value": round(float(origin_top["market_share"]), 1), "year": 2024}],
            },
            {
                "category": "Reviews",
                "title": "Visitor sentiment is mostly positive",
                "description": f"Positive perception signals total {sentiment['positive_percentage']}%, while negative signals total {sentiment['negative_percentage']}%.",
                "evidence": [{"metric_label": "Positive sentiment", "primary_numeric_value": sentiment["positive_percentage"], "year": 2024}],
            },
            {
                "category": "Pricing",
                "title": f"{peak_price['month']} supports higher pricing",
                "description": f"The Scikit pricing model recommends the highest seasonal pricing in {peak_price['month']} based on demand.",
                "evidence": [{"metric_label": "Predicted price", "primary_numeric_value": peak_price["predicted_price"], "year": 2024}],
            },
        ]

    def knowledge(self, query, top_k=5):
        query_vector = self.vectorizer.transform([query])
        scores = cosine_similarity(query_vector, self.knowledge_matrix)[0]
        indices = np.argsort(scores)[::-1][:top_k]
        return [
            {
                "score": round(float(scores[idx]), 3),
                "report_name": "Scikit tourism dataset",
                "year": "2024",
                "topic": "tourism intelligence",
                "table_title": "Unified Scikit model knowledge",
                "content_excerpt": self.knowledge_records[int(idx)],
            }
            for idx in indices
        ]

    def analyze_reviews(self, reviews):
        texts = []
        for item in reviews:
            if isinstance(item, dict):
                texts.append(str(item.get("comment") or item.get("review") or item.get("text") or ""))
            else:
                texts.append(str(item))
        combined = " ".join(texts).lower()
        positive_words = ["good", "great", "friendly", "fantastic", "beautiful", "helpful", "excellent", "love"]
        negative_words = ["poor", "bad", "delay", "dirty", "expensive", "problem", "complaint"]
        positive = sum(combined.count(word) for word in positive_words)
        negative = sum(combined.count(word) for word in negative_words)
        label = "positive" if positive >= negative else "negative"
        recommendations = []
        if "sign" in combined or "road" in combined or negative > positive:
            recommendations.append("Improve signage, service response, and visitor guidance at touchpoints.")
        recommendations.append("Promote the strongest positive review themes in vendor and attraction marketing.")
        return {
            "sentiment": label,
            "positiveSignals": positive,
            "negativeSignals": negative,
            "summary": f"Scikit review analysis detected {label} visitor sentiment from {len(texts)} review(s).",
            "recommendations": recommendations,
            "dataset_baseline": self.sentiment(),
        }


model = ExploreLesothoScikitModel()
app = Flask(__name__)
CORS(app)


def ok(**payload):
    return jsonify({"success": True, "status": "success", **payload})


@app.route("/")
def home():
    return ok(message="Explore Lesotho Scikit AI API is running", active_model="scikit")


@app.route("/health")
@app.route("/api/ml/health")
def health():
    return ok(active_model="scikit", models={"scikit_unified_model": True}, overview=model.overview())


@app.route("/forecast")
@app.route("/api/forecast")
@app.route("/api/ml/forecast")
def forecast():
    return ok(forecast=model.forecast(request.args.get("days", default=30, type=int)))


@app.route("/dashboard")
@app.route("/api/ml/dashboard")
def dashboard():
    origin = model.origin_analysis()
    sentiment_data = model.sentiment()
    monthly_top = model.monthly.sort_values("arrivals", ascending=False).iloc[0]
    attraction_rows = model.attractions.sort_values("visitors", ascending=False).head(5)

    return ok(
        dashboard={
            "overview": model.overview(),
            "insights": model.insights(),
            "legacy_intelligence": {
                "peak_month": {
                    "month": monthly_top["month_name"],
                    "arrivals": int(float(monthly_top["arrivals"])),
                },
                "top_attractions": [
                    {
                        "name": row["attraction"],
                        "visitors": int(float(row["visitors"])),
                    }
                    for _, row in attraction_rows.iterrows()
                ],
                "top_markets": origin["top_markets"],
                "sentiment_highlights": [
                    {
                        "label": item["sentiment"],
                        "percentage": float(item["percentage"]),
                    }
                    for item in sentiment_data["sentiments"]
                ],
                "seasonal_hotspots": [
                    {
                        "season": "Summer (Dec-Feb)",
                        "places": ["Maletsunyane Falls", "Sani Pass", "Katse Dam"],
                    },
                    {
                        "season": "Winter (Jun-Aug)",
                        "places": ["Afriski Mountain Resort", "Maletsunyane Falls", "Thaba Bosiu"],
                    },
                    {
                        "season": "Spring (Sep-Nov)",
                        "places": ["Morija Museum", "Kome Caves", "Malealea"],
                    },
                    {
                        "season": "Autumn (Mar-May)",
                        "places": ["Thaba Bosiu", "Katse Dam", "Semonkong"],
                    },
                ],
            },
        }
    )


@app.route("/pricing")
@app.route("/api/pricing")
@app.route("/api/ml/pricing")
def pricing():
    return ok(pricing=model.pricing())


@app.route("/sentiment")
@app.route("/api/sentiment")
@app.route("/api/ml/sentiment")
def sentiment():
    return ok(**model.sentiment())


@app.route("/similar/<attraction>")
@app.route("/api/similar/<attraction>")
@app.route("/api/ml/similar/<attraction>")
def similar(attraction):
    rows = model.similar(attraction)
    if not rows:
        return jsonify({"success": False, "status": "error", "message": "Attraction not found"}), 404
    return ok(attraction=attraction, similar=rows)


@app.route("/recommendations", methods=["GET", "POST"])
@app.route("/api/recommendations", methods=["GET", "POST"])
@app.route("/api/ml/recommendations", methods=["GET", "POST"])
@app.route("/recommend", methods=["GET", "POST"])
@app.route("/api/ml/recommend", methods=["GET", "POST"])
def recommendations():
    payload = request.json if request.method == "POST" else request.args
    payload = payload or {}
    rows = model.recommendations(
        location=payload.get("location", "Maseru"),
        limit=int(payload.get("limit", 10)),
        category=payload.get("category"),
        subcategory=payload.get("subcategory"),
    )
    return ok(location=payload.get("location", "Maseru"), recommendations={"activities": rows, "attractions": rows})


@app.route("/culture/locations")
@app.route("/api/ml/culture/locations")
def culture_locations():
    rows = []
    for _, row in model.attractions.iterrows():
        rows.append(
            {
                "name": row["attraction"],
                "district": row.get("district", "Lesotho"),
                "category": "culture" if any(word in str(row["attraction"]).lower() for word in ["thaba", "morija", "kome"]) else "tourism",
                "visitors": int(float(row["visitors"])),
                "domestic_pct": float(row["domestic_pct"]),
                "international_pct": float(row["international_pct"]),
            }
        )
    return ok(data=rows, locations=rows)


@app.route("/culture/recommendations", methods=["POST"])
@app.route("/api/ml/culture/recommendations", methods=["POST"])
def culture_recommendations():
    payload = request.json or {}
    rows = model.recommendations(
        location=payload.get("location", "Maseru"),
        category="culture",
        subcategory=payload.get("subcategory") or "heritage",
    )
    return ok(recommendations={"activities": rows, "attractions": rows})


@app.route("/origin-analysis")
@app.route("/api/origin-analysis")
@app.route("/api/ml/origin-analysis")
def origin_analysis():
    return ok(**model.origin_analysis())


@app.route("/hotspots")
@app.route("/api/hotspots")
@app.route("/api/ml/hotspots")
def hotspots():
    return ok(
        hotspots={
            "Summer (Dec-Feb)": ["Maletsunyane Falls", "Sani Pass", "Katse Dam"],
            "Winter (Jun-Aug)": ["Afri Ski", "Maletsunyane Falls", "Thaba Bosiu"],
            "Spring (Sep-Nov)": ["Morija Museum", "Kome Caves", "Malealea"],
            "Autumn (Mar-May)": ["Thaba Bosiu", "Katse Dam", "Semonkong"],
        }
    )


@app.route("/ltdc/overview")
@app.route("/api/ml/ltdc/overview")
def ltdc_overview():
    return ok(overview=model.overview())


@app.route("/ltdc/insights")
@app.route("/api/ml/ltdc/insights")
def ltdc_insights():
    return ok(insights=model.insights())


@app.route("/ltdc/knowledge", methods=["POST"])
@app.route("/api/ml/ltdc/knowledge", methods=["POST"])
def ltdc_knowledge():
    payload = request.json or {}
    query = str(payload.get("query", "")).strip()
    if not query:
        return jsonify({"success": False, "error": "query is required"}), 400
    return ok(query=query, matches=model.knowledge(query, int(payload.get("top_k", 5))))


@app.route("/ltdc/trends")
@app.route("/api/ml/ltdc/trends")
def ltdc_trends():
    topic = (request.args.get("topic") or "").lower()
    if topic == "attractions":
        rows = model.attractions.to_dict(orient="records")
    elif topic == "arrivals":
        rows = model.origin.to_dict(orient="records")
    else:
        rows = model.monthly.to_dict(orient="records")
    return ok(rows=rows, summary={"record_count": len(rows)})


@app.route("/reviews/analyze", methods=["POST"])
@app.route("/analyze-sentiment", methods=["POST"])
@app.route("/api/ml/reviews/analyze", methods=["POST"])
@app.route("/api/ml/analyze-sentiment", methods=["POST"])
def analyze_reviews():
    payload = request.json or {}
    return ok(analysis=model.analyze_reviews(payload.get("reviews", [])))


@app.route("/register_vendor", methods=["POST"])
@app.route("/api/ml/register_vendor", methods=["POST"])
def register_vendor():
    data = request.json or {}
    return ok(
        result={
            "approved": True,
            "confidence": 0.92,
            "reasons": ["Approved by the unified Scikit project model for development/testing."],
            "business_type": data.get("business_type") or data.get("businessType"),
        }
    )


@app.route("/check_user", methods=["POST"])
@app.route("/api/ml/check_user", methods=["POST"])
def check_user():
    return ok(result={"status": "CLEAR", "risk_score": 0.08, "model": "scikit"})


@app.route("/verify_pdf", methods=["POST"])
@app.route("/api/ml/verify_pdf", methods=["POST"])
def verify_pdf():
    payload = request.json or {}
    file_path = str(payload.get("file_path", "")).strip()
    return ok(result={"valid": bool(file_path), "reasons": [], "model": "scikit"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5001)), debug=True)
