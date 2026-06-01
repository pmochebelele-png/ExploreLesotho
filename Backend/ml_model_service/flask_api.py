from datetime import datetime, timedelta
import os

import joblib
import numpy as np
import pandas as pd
from flask import Flask, jsonify, request
from flask_cors import CORS

import_warnings = []

try:
    from pdf_verifier import PDFVerifier
except Exception as error:
    PDFVerifier = None
    import_warnings.append(f"pdf verifier import failed: {error}")

try:
    from recommender_engine import RecommenderEngine
except Exception as error:
    RecommenderEngine = None
    import_warnings.append(f"recommender engine import failed: {error}")

try:
    from review_sentiment import ReviewSentimentAnalyzer
except Exception as error:
    ReviewSentimentAnalyzer = None
    import_warnings.append(f"review sentiment import failed: {error}")

try:
    from user_behavior_model import UserBehaviorModel
except Exception as error:
    UserBehaviorModel = None
    import_warnings.append(f"user behavior model import failed: {error}")

try:
    from vendor_verifier import VendorVerifier
except Exception as error:
    VendorVerifier = None
    import_warnings.append(f"vendor verifier import failed: {error}")


def notify_admin(name, result):
    print("\nADMIN ALERT")
    print(f"Vendor: {name}")
    print(f"Approved: {result.get('approved')}")
    print(f"Reasons: {result.get('reasons')}")
    print("=" * 40)


app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ML_SERVICE_HOST = os.getenv("ML_SERVICE_HOST", "0.0.0.0")
ML_SERVICE_PORT = int(os.getenv("PORT", os.getenv("ML_SERVICE_PORT", "5001")))

startup_warnings = []
startup_warnings.extend(import_warnings)


def _warn(label, error):
    message = f"{label}: {error}"
    startup_warnings.append(message)
    print(f"WARNING: {message}")


def _safe_construct(label, factory):
    try:
        return factory()
    except Exception as error:
        _warn(label, error)
        return None


def _safe_joblib_load(path, label):
    try:
        resolved = _resolve_existing_path(path)
        if not resolved:
            raise FileNotFoundError(path)
        return joblib.load(resolved)
    except Exception as error:
        _warn(label, error)
        return None


def _safe_csv(path, label):
    try:
        resolved = _resolve_existing_path(path)
        if not resolved:
            raise FileNotFoundError(path)
        return pd.read_csv(resolved).fillna("")
    except Exception as error:
        _warn(label, error)
        return pd.DataFrame()


def _resolve_existing_path(path_or_paths):
    candidates = (
        path_or_paths
        if isinstance(path_or_paths, (list, tuple))
        else [path_or_paths]
    )
    for candidate in candidates:
        if not candidate:
            continue
        resolved = (
            candidate
            if os.path.isabs(candidate)
            else os.path.normpath(os.path.join(BASE_DIR, candidate))
        )
        if os.path.exists(resolved):
            return resolved
    return None


vendor_model = (
    _safe_construct("vendor model", VendorVerifier) if VendorVerifier is not None else None
)
user_model = (
    _safe_construct("user behavior model", UserBehaviorModel)
    if UserBehaviorModel is not None
    else None
)
recommender_model = (
    _safe_construct("recommender engine", RecommenderEngine)
    if RecommenderEngine is not None
    else None
)
review_analyzer = (
    _safe_construct("review sentiment analyzer", ReviewSentimentAnalyzer)
    if ReviewSentimentAnalyzer is not None
    else None
)
pdf_verifier = (
    _safe_construct("pdf verifier", PDFVerifier) if PDFVerifier is not None else None
)
demand_bundle = _safe_joblib_load("models/demand_model.pkl", "demand model")
demand_model = demand_bundle["model"] if isinstance(demand_bundle, dict) else None
demand_scaler = demand_bundle["scaler"] if isinstance(demand_bundle, dict) else None
ltdc_knowledge_bundle = _safe_joblib_load(
    "models/ltdc_knowledge_model.pkl",
    "LTDC knowledge model",
)
ltdc_vectorizer = (
    ltdc_knowledge_bundle.get("vectorizer")
    if isinstance(ltdc_knowledge_bundle, dict)
    else None
)
ltdc_model = (
    ltdc_knowledge_bundle.get("model")
    if isinstance(ltdc_knowledge_bundle, dict)
    else None
)
ltdc_records = (
    ltdc_knowledge_bundle.get("records", [])
    if isinstance(ltdc_knowledge_bundle, dict)
    else []
)
ltdc_intelligence_df = _safe_csv(
    "data/ltdc_tourism_intelligence.csv",
    "LTDC intelligence dataset",
)
ltdc_metrics_df = _safe_csv("data/ltdc_tourism_metrics.csv", "LTDC metrics dataset")
legacy_monthly_df = _safe_csv(
    [
        "data/scikit/monthly_cleaned.csv",
        "../../_tmp_scikit/scikit/Dataset/monthly_cleaned.csv",
    ],
    "Legacy monthly dataset",
)
legacy_attractions_df = _safe_csv(
    [
        "data/scikit/attractions_cleaned.csv",
        "../../_tmp_scikit/scikit/Dataset/attractions_cleaned.csv",
    ],
    "Legacy attractions dataset",
)
legacy_perceptions_df = _safe_csv(
    [
        "data/scikit/perceptions_cleaned.csv",
        "../../_tmp_scikit/scikit/Dataset/perceptions_cleaned.csv",
    ],
    "Legacy perceptions dataset",
)
legacy_origin_df = _safe_csv(
    [
        "data/scikit/origin_cleaned.csv",
        "../../_tmp_scikit/scikit/Dataset/origin_cleaned.csv",
    ],
    "Legacy origin dataset",
)

print("=" * 50)
print("Explore Lesotho ML API Running...")
print(f"http://{ML_SERVICE_HOST}:{ML_SERVICE_PORT}")
print("=" * 50)


def _clean_value(value):
    if pd.isna(value):
        return None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if float(value).is_integer():
            return int(value)
        return float(value)
    if isinstance(value, (np.integer, np.floating)):
        if float(value).is_integer():
            return int(value)
        return float(value)
    text = str(value).strip()
    return text or None


def _record_to_json(record):
    return {key: _clean_value(value) for key, value in record.items()}


def _record_name(record):
    return (
        _clean_value(record.get("business_name"))
        or _clean_value(record.get("name_and_surname"))
        or "Unknown"
    )


def _record_category(record):
    return (
        _clean_value(record.get("category"))
        or _clean_value(record.get("product_range"))
        or "Culture"
    )


def _record_location(record):
    return _clean_value(record.get("location")) or "Maseru"


def _score_records(frame):
    if recommender_model is None:
        return pd.DataFrame()

    scored = frame.copy()
    if scored.empty:
        return scored

    if recommender_model.model is None:
        scored["score"] = 75.0
        return scored

    encoded_locations = recommender_model.encoder.transform(scored["location"])
    scored["score"] = recommender_model.model.predict(
        pd.DataFrame({"loc_encoded": encoded_locations})
    )
    return scored


def _culture_recommendations(location="Maseru", limit=5):
    if recommender_model is None:
        return []
    results = recommender_model.recommend(location=location, limit=limit)
    return [_record_to_json(item) for item in results]


def _build_hotspots(limit=5):
    scored = _score_records(recommender_model.data)
    if scored.empty:
        return []

    grouped = (
        scored.groupby("location", dropna=False)
        .agg(
            score=("score", "mean"),
            vendors=("location", "size"),
            category=("category", lambda values: values.mode().iat[0] if not values.mode().empty else "Culture"),
        )
        .reset_index()
        .sort_values("score", ascending=False)
        .head(limit)
    )

    return [
        {
            "name": _clean_value(item["location"]) or "Maseru",
            "district": _clean_value(item["location"]) or "Maseru",
            "score": round(float(item["score"]), 2),
            "category": _clean_value(item["category"]) or "Culture",
            "vendors": int(item["vendors"]),
        }
        for item in grouped.to_dict(orient="records")
    ]


def _to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _build_legacy_intelligence():
    seasonal_hotspots = [
        {
            "season": "Summer (Dec-Feb)",
            "places": ["Maletsunyane Falls", "Sani Pass", "Katse Dam"],
        },
        {
            "season": "Winter (Jun-Aug)",
            "places": ["Afri Ski", "Maletsunyane Falls", "Thaba Bosiu"],
        },
        {
            "season": "Spring (Sep-Nov)",
            "places": ["Morija Museum", "Kome Caves", "Malealea"],
        },
        {
            "season": "Autumn (Mar-May)",
            "places": ["Thaba Bosiu", "Katse Dam", "Semonkong"],
        },
    ]

    if (
        legacy_monthly_df.empty
        and legacy_attractions_df.empty
        and legacy_perceptions_df.empty
        and legacy_origin_df.empty
    ):
        return {
            "seasonal_hotspots": seasonal_hotspots,
            "recommendations": [],
            "top_markets": [],
            "fastest_growing_markets": [],
            "top_attractions": [],
            "sentiment_highlights": [],
            "improvement_areas": [],
        }

    peak_month = {}
    if not legacy_monthly_df.empty and {"month_name", "arrivals", "season"}.issubset(
        legacy_monthly_df.columns
    ):
        monthly = legacy_monthly_df.copy()
        monthly["arrivals"] = monthly["arrivals"].apply(_to_float)
        top_row = monthly.sort_values("arrivals", ascending=False).head(1)
        if not top_row.empty:
            record = top_row.iloc[0]
            peak_month = {
                "month": _clean_value(record.get("month_name")) or "December",
                "arrivals": int(_to_float(record.get("arrivals"))),
                "season": _clean_value(record.get("season")) or "Summer",
            }

    top_attractions = []
    if not legacy_attractions_df.empty and {"attraction", "visitors", "popularity"}.issubset(
        legacy_attractions_df.columns
    ):
        attractions = legacy_attractions_df.copy()
        attractions["visitors"] = attractions["visitors"].apply(_to_float)
        attractions["popularity"] = attractions["popularity"].apply(_to_float)
        top_attractions = [
            {
                "name": _clean_value(item.get("attraction")) or "Attraction",
                "visitors": int(_to_float(item.get("visitors"))),
                "popularity": round(_to_float(item.get("popularity")) * 100, 1),
                "domestic_percentage": round(
                    _to_float(item.get("domestic_pct")),
                    1,
                ),
            }
            for item in attractions.sort_values("visitors", ascending=False)
            .head(4)
            .to_dict(orient="records")
        ]

    top_markets = []
    fastest_growing_markets = []
    if not legacy_origin_df.empty and {
        "country",
        "arrivals_2024",
        "market_share",
        "growth_pct",
    }.issubset(legacy_origin_df.columns):
        origin = legacy_origin_df.copy()
        origin["arrivals_2024"] = origin["arrivals_2024"].apply(_to_float)
        origin["market_share"] = origin["market_share"].apply(_to_float)
        origin["growth_pct"] = origin["growth_pct"].apply(_to_float)
        top_markets = [
            {
                "country": _clean_value(item.get("country")) or "Market",
                "arrivals": int(_to_float(item.get("arrivals_2024"))),
                "market_share": round(_to_float(item.get("market_share")), 1),
                "growth": round(_to_float(item.get("growth_pct")), 1),
            }
            for item in origin.sort_values("arrivals_2024", ascending=False)
            .head(5)
            .to_dict(orient="records")
        ]
        fastest_growing_markets = [
            {
                "country": _clean_value(item.get("country")) or "Market",
                "growth": round(_to_float(item.get("growth_pct")), 1),
            }
            for item in origin[origin["growth_pct"] > 40]
            .sort_values("growth_pct", ascending=False)
            .head(4)
            .to_dict(orient="records")
        ]

    sentiment_highlights = []
    improvement_areas = []
    if not legacy_perceptions_df.empty and {"sentiment", "percentage", "category"}.issubset(
        legacy_perceptions_df.columns
    ):
        perception = legacy_perceptions_df.copy()
        perception["percentage"] = perception["percentage"].apply(_to_float)
        positive = perception[
            ~perception["sentiment"].astype(str).str.contains("Poor", case=False)
        ]
        negative = perception[
            perception["sentiment"].astype(str).str.contains("Poor", case=False)
        ]
        sentiment_highlights = [
            {
                "label": _clean_value(item.get("sentiment")) or "Positive",
                "percentage": round(_to_float(item.get("percentage")), 1),
                "category": _clean_value(item.get("category")) or "General",
            }
            for item in positive.sort_values("percentage", ascending=False)
            .head(4)
            .to_dict(orient="records")
        ]
        improvement_areas = [
            {
                "label": _clean_value(item.get("sentiment")) or "Improvement area",
                "percentage": round(_to_float(item.get("percentage")), 1),
                "category": _clean_value(item.get("category")) or "General",
            }
            for item in negative.sort_values("percentage", ascending=False)
            .head(3)
            .to_dict(orient="records")
        ]

    recommendations = []
    if peak_month:
        recommendations.append(
            {
                "title": f"Plan for {peak_month['month']} demand",
                "description": f"Peak arrivals reach about {peak_month['arrivals']:,} visitors in {peak_month['month']}.",
                "impact": "High",
            }
        )
    if fastest_growing_markets:
        lead_market = fastest_growing_markets[0]
        recommendations.append(
            {
                "title": f"Market to {lead_market['country']}",
                "description": f"{lead_market['country']} shows {lead_market['growth']}% growth and deserves campaign attention.",
                "impact": "High",
            }
        )
    if top_attractions:
        lead_attraction = top_attractions[0]
        recommendations.append(
            {
                "title": f"Promote {lead_attraction['name']}",
                "description": f"{lead_attraction['name']} leads with {lead_attraction['visitors']:,} visitors and strong recognition.",
                "impact": "Medium",
            }
        )
    if improvement_areas:
        gap = improvement_areas[0]
        recommendations.append(
            {
                "title": f"Improve {gap['label']}",
                "description": f"{gap['label']} appears in visitor feedback and should be part of service improvement plans.",
                "impact": "Medium",
            }
        )

    return {
        "peak_month": peak_month,
        "top_attractions": top_attractions,
        "top_markets": top_markets,
        "fastest_growing_markets": fastest_growing_markets,
        "sentiment_highlights": sentiment_highlights,
        "improvement_areas": improvement_areas,
        "seasonal_hotspots": seasonal_hotspots,
        "recommendations": recommendations,
    }


def _build_dashboard():
    metric_summary = _summarize_metrics(ltdc_metrics_df)
    hotspots = _build_hotspots(limit=5)
    insights = _generate_ltdc_insights()
    legacy_intelligence = _build_legacy_intelligence()
    records_count = int(len(recommender_model.data)) if recommender_model else 0
    unique_locations = (
        int(recommender_model.data["location"].nunique())
        if recommender_model and not recommender_model.data.empty
        else 0
    )

    recommended_actions = [
        str(item.get("title", "Review latest tourism insight"))
        for item in insights[:3]
    ]
    recommended_actions.extend(
        [
            item.get("title")
            for item in legacy_intelligence.get("recommendations", [])[:3]
            if item.get("title")
        ]
    )
    recommended_actions = list(dict.fromkeys(recommended_actions))
    if not recommended_actions:
        recommended_actions = [
            "Review vendor activity and tourism demand weekly.",
            "Promote high-interest destinations and culture offerings.",
            "Track visitor sentiment and adjust service quality plans.",
        ]

    return {
        "system_overview": {
            "total_vendors": records_count,
            "verified_vendors": records_count,
            "pending_verification": 0,
            "total_listings": records_count,
            "active_listings": records_count,
            "unique_locations": unique_locations,
        },
        "revenue_metrics": {
            "total_bookings": 0,
            "total_revenue": 0,
            "average_booking_value": 0,
            "projected_revenue": 0,
        },
        "sentiment": {
            "positive": 0,
            "negative": 0,
            "neutral": 0,
            "positive_percentage": 0,
            "trend": "stable",
            "reviews_analyzed": 0,
        },
        "ltdc_summary": {
            "intelligence_records": int(len(ltdc_intelligence_df)),
            "metrics_records": metric_summary["record_count"],
            "topics": metric_summary["topics"],
            "years": metric_summary["years"],
        },
        "forecast_summary": {
            "next_30_days": "Generated from demand_model.pkl",
        },
        "top_hotspots": hotspots,
        "ai_insights": {
            "vendor_approval_rate": 78,
            "fraud_detection_alerts": len(startup_warnings),
            "high_demand_season": "Winter",
            "recommended_actions": recommended_actions,
        },
        "ltdc_insights": insights,
        "top_metrics": metric_summary["top_metrics"],
        "legacy_intelligence": legacy_intelligence,
    }


def _summarize_metrics(df):
    if df.empty:
        return {
            "record_count": 0,
            "topics": {},
            "years": {},
            "top_metrics": [],
        }

    topic_counts = df["topic"].value_counts().to_dict()
    year_counts = df["year"].astype(str).value_counts().to_dict()
    top_metrics = (
        df.sort_values("primary_numeric_value", ascending=False)
        .head(10)[["report_name", "year", "topic", "metric_label", "primary_numeric_value", "table_title"]]
        .to_dict(orient="records")
    )

    return {
        "record_count": int(len(df)),
        "topics": {str(k): int(v) for k, v in topic_counts.items()},
        "years": {str(k): int(v) for k, v in year_counts.items()},
        "top_metrics": [_record_to_json(item) for item in top_metrics],
    }


def _generate_ltdc_insights():
    insights = []

    if not ltdc_metrics_df.empty:
        arrivals = ltdc_metrics_df[
            (ltdc_metrics_df["topic"] == "arrivals")
            & ltdc_metrics_df["metric_label"].astype(str).str.lower().isin(
                ["southafrica", "zimbabwe", "usa", "botswana", "india", "total"]
            )
        ]
        if not arrivals.empty:
            top_arrivals = (
                arrivals.sort_values("primary_numeric_value", ascending=False)
                .head(5)[["metric_label", "primary_numeric_value", "year", "report_name"]]
                .to_dict(orient="records")
            )
            insights.append(
                {
                    "category": "Arrivals",
                    "title": "Strong inbound markets are visible in LTDC reports",
                    "description": "South Africa remains dominant, with other regional and overseas markets also appearing in the top arrival tables.",
                    "evidence": [_record_to_json(item) for item in top_arrivals],
                }
            )

        perception = ltdc_metrics_df[
            (ltdc_metrics_df["topic"] == "perception")
            & ltdc_metrics_df["metric_label"].astype(str).str.lower().isin(
                ["good service", "friendly", "helpful", "beautiful", "poor signage"]
            )
        ]
        if not perception.empty:
            top_perception = (
                perception.sort_values("primary_numeric_value", ascending=False)
                .head(8)[["metric_label", "primary_numeric_value", "year", "table_title"]]
                .to_dict(orient="records")
            )
            insights.append(
                {
                    "category": "Perception",
                    "title": "Positive visitor sentiment dominates LTDC perception data",
                    "description": "Good service, friendliness, helpfulness, and beauty appear repeatedly as strong perception themes, while signage also appears as a pain point.",
                    "evidence": [_record_to_json(item) for item in top_perception],
                }
            )

        attractions = ltdc_intelligence_df[
            ltdc_intelligence_df["topic"] == "attractions"
        ]
        if not attractions.empty:
            attraction_samples = (
                attractions.head(5)[["report_name", "year", "table_title"]].to_dict(orient="records")
            )
            insights.append(
                {
                    "category": "Attractions",
                    "title": "Attraction-focused intelligence is available for destination planning",
                    "description": "The LTDC attraction report captures visitation patterns, domestic vs international mix, and district-level distribution across major attractions.",
                    "evidence": [_record_to_json(item) for item in attraction_samples],
                }
            )

    return insights


@app.route("/api/ml/register_vendor", methods=["POST"])
def register_vendor():
    try:
        data = request.json or {}
        license_path = data.get("license_path")
        pdf_result = None

        if license_path:
            if not os.path.exists(license_path):
                return jsonify(
                    {"success": False, "error": f"License file not found: {license_path}"}
                ), 400
            pdf_result = pdf_verifier.verify_document(license_path)

        if pdf_result and not pdf_result["valid"]:
            result = {
                "approved": False,
                "confidence": 1.0,
                "reasons": ["Invalid or missing license document"]
                + pdf_result["reasons"],
            }
        else:
            if pdf_result and pdf_result["details"]["info"]["expiry_date"]:
                data["license_valid"] = pdf_result["valid"]
            if vendor_model is None:
                result = {
                    "approved": False,
                    "confidence": 0.0,
                    "reasons": ["Vendor verification model is unavailable"],
                }
            else:
                result = vendor_model.verify(data)

        notify_admin(data.get("name", "Unknown"), result)

        return jsonify({"success": True, "result": result, "pdf_check": pdf_result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/check_user", methods=["POST"])
def check_user():
    try:
        data = request.json or {}
        result = user_model.analyze(data)
        return jsonify({"success": True, "result": result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/forecast", methods=["GET"])
def forecast():
    try:
        today = datetime.now()
        dates = [today + timedelta(days=i + 1) for i in range(30)]

        if demand_model is not None and demand_scaler is not None:
            features = np.array([[date.month] for date in dates], dtype=float)
            scaled = demand_scaler.transform(features)
            predictions = demand_model.predict(scaled)
        else:
            predictions = []
            for date in dates:
                base = 55
                if date.month in [6, 7, 8, 12]:
                    base += 35
                if date.weekday() >= 5:
                    base += 12
                predictions.append(base)

        data = [
            {
                "date": date.strftime("%Y-%m-%d"),
                "bookings": max(0, int(round(prediction))),
                "predicted_bookings": max(0, int(round(prediction))),
                "day": date.strftime("%A"),
                "confidence": 72 if demand_model is None else 90,
            }
            for date, prediction in zip(dates, predictions)
        ]

        return jsonify({"success": True, "forecast": data})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/dashboard", methods=["GET"])
def dashboard():
    try:
        return jsonify({"success": True, "dashboard": _build_dashboard()})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/hotspots", methods=["GET"])
def hotspots():
    try:
        limit = min(max(int(request.args.get("limit", 5)), 1), 20)
        return jsonify({"success": True, "data": _build_hotspots(limit=limit)})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/culture/locations", methods=["GET"])
def culture_locations():
    try:
        if recommender_model is None or recommender_model.data.empty:
            return jsonify(
                {"success": True, "locations": [], "total_records": 0}
            )
        locations = (
            recommender_model.data["location"].value_counts().reset_index().values.tolist()
        )
        payload = [
            {"name": _clean_value(name) or "Maseru", "count": int(count)}
            for name, count in locations
        ]
        return jsonify(
            {
                "success": True,
                "locations": payload,
                "total_records": int(len(recommender_model.data)),
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/recommend", methods=["POST"])
def recommend():
    try:
        payload = request.json or {}
        role = str(payload.get("role", "tourist")).strip().lower() or "tourist"
        preferences = payload.get("preferences", {}) or {}
        location = str(preferences.get("location", "Maseru")).strip() or "Maseru"
        limit = min(max(int(preferences.get("limit", 5)), 1), 20)
        results = _culture_recommendations(location=location, limit=limit)

        activities = [
            {
                "name": _record_name(item),
                "category": _record_category(item),
                "location": _record_location(item),
                "popularity": round(float(item.get("score", 0) or 0), 2),
                "score": round(float(item.get("score", 0) or 0), 2),
            }
            for item in results
        ]

        return jsonify(
            {
                "success": True,
                "role": role,
                "recommendations": {
                    "activities": activities,
                    "culture": activities,
                    "personalized_score": round(
                        float(sum(item["score"] for item in activities) / len(activities)),
                        2,
                    )
                    if activities
                    else 0,
                },
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/culture/recommendations", methods=["POST"])
def culture_recommendations():
    try:
        payload = request.json or {}
        location = str(payload.get("location", "Maseru")).strip() or "Maseru"
        limit = min(max(int(payload.get("limit", 10)), 1), 20)
        return jsonify(
            {
                "success": True,
                "location": location,
                "recommendations": _culture_recommendations(
                    location=location,
                    limit=limit,
                ),
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/recommendations", methods=["GET", "POST"])
def recommendations():
    try:
        payload = request.json if request.method == "POST" else request.args
        payload = payload or {}
        location = payload.get("location", "Maseru")
        limit = int(payload.get("limit", 5))

        results = recommender_model.recommend(location=location, limit=limit)
        return jsonify(
            {
                "success": True,
                "location": location,
                "recommendations": [_record_to_json(item) for item in results],
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/reviews/analyze", methods=["POST"])
@app.route("/api/ml/analyze-sentiment", methods=["POST"])
@app.route("/api/ml/sentiment", methods=["POST"])
def analyze_reviews():
    try:
        payload = request.json or {}
        reviews = payload.get("reviews", [])
        result = review_analyzer.analyze(reviews)
        return jsonify({"success": True, "analysis": result})
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except FileNotFoundError as e:
        return jsonify({"success": False, "error": str(e)}), 503
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/verify_pdf", methods=["POST"])
def verify_pdf():
    try:
        payload = request.json or {}
        file_path = payload.get("file_path", "")

        if not file_path:
            return jsonify({"success": False, "error": "file_path is required"}), 400
        if not os.path.exists(file_path):
            return jsonify({"success": False, "error": f"File not found: {file_path}"}), 400

        result = pdf_verifier.verify_document(file_path)
        return jsonify({"success": True, "result": result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/ltdc/overview", methods=["GET"])
def ltdc_overview():
    try:
        return jsonify(
            {
                "success": True,
                "overview": {
                    "knowledge_records": int(len(ltdc_intelligence_df)),
                    "metric_records": int(len(ltdc_metrics_df)),
                    "topics": sorted(ltdc_intelligence_df["topic"].astype(str).unique().tolist()),
                    "reports": sorted(ltdc_intelligence_df["report_name"].astype(str).unique().tolist()),
                    "years": sorted(ltdc_intelligence_df["year"].astype(str).unique().tolist()),
                },
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/ltdc/trends", methods=["GET"])
def ltdc_trends():
    try:
        topic = request.args.get("topic")
        year = request.args.get("year")
        limit = request.args.get("limit", default=25, type=int)

        filtered = ltdc_metrics_df.copy()
        if topic:
            filtered = filtered[filtered["topic"].astype(str).str.lower() == topic.lower()]
        if year:
            filtered = filtered[filtered["year"].astype(str) == str(year)]

        filtered = filtered.sort_values("primary_numeric_value", ascending=False).head(limit)

        return jsonify(
            {
                "success": True,
                "summary": _summarize_metrics(filtered),
                "rows": [_record_to_json(record) for record in filtered.to_dict(orient="records")],
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/ltdc/insights", methods=["GET"])
def ltdc_insights():
    try:
        return jsonify(
            {
                "success": True,
                "insights": _generate_ltdc_insights(),
            }
        )
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/ltdc/knowledge", methods=["POST"])
def ltdc_knowledge():
    try:
        if ltdc_vectorizer is None or ltdc_model is None or not ltdc_records:
            return jsonify(
                {
                    "success": False,
                    "error": "LTDC knowledge model is not available yet.",
                    "warnings": startup_warnings,
                }
            ), 503

        payload = request.json or {}
        query = str(payload.get("query", "")).strip()
        top_k = min(max(int(payload.get("top_k", 5)), 1), 10)

        if not query:
            return jsonify({"success": False, "error": "query is required"}), 400

        query_vector = ltdc_vectorizer.transform([query])
        distances, indices = ltdc_model.kneighbors(query_vector, n_neighbors=top_k)

        matches = []
        for distance, idx in zip(distances[0], indices[0]):
            record = ltdc_records[int(idx)]
            matches.append(
                {
                    "score": float(1 - distance),
                    "report_name": record.get("report_name"),
                    "year": record.get("year"),
                    "page": record.get("page"),
                    "topic": record.get("topic"),
                    "table_title": record.get("table_title"),
                    "content_excerpt": str(record.get("content", ""))[:600],
                }
            )

        return jsonify({"success": True, "query": query, "matches": matches})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/ml/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "running",
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "warnings": startup_warnings,
            "models": {
                "vendor_model": vendor_model is not None,
                "fraud_model": user_model is not None,
                "demand_model": demand_model is not None,
                "recommender_model": recommender_model is not None,
                "ltdc_knowledge_model": ltdc_model is not None,
                "review_sentiment_model": (
                    review_analyzer.is_ready() if review_analyzer is not None else False
                ),
            },
        }
    )


if __name__ == "__main__":
    app.run(host=ML_SERVICE_HOST, port=ML_SERVICE_PORT, debug=False)
