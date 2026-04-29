# ml_model/review_sentiment.py

from collections import Counter
from datetime import datetime
import os
import re

import joblib


class ReviewSentimentAnalyzer:
    def __init__(self, model_path="models/review_sentiment_model.pkl"):
        self.model_path = model_path
        self.pipeline = None
        self.metadata = {}
        self.stopwords = {
            "about",
            "after",
            "also",
            "and",
            "are",
            "but",
            "for",
            "from",
            "have",
            "into",
            "the",
            "this",
            "that",
            "was",
            "were",
            "with",
            "you",
        }
        self.load_model(required=False)

    def load_model(self, required=True):
        if not os.path.exists(self.model_path):
            if required:
                raise FileNotFoundError(
                    f"{self.model_path} not found. Train it with train_review_sentiment.py using real labeled reviews."
                )
            return self

        bundle = joblib.load(self.model_path)
        self.pipeline = bundle["pipeline"]
        self.metadata = bundle.get("metadata", {})
        return self

    def is_ready(self):
        return self.pipeline is not None

    def _tokens(self, text):
        return re.findall(r"[a-z']+", str(text).lower())

    def _comment(self, review):
        return str(review.get("comment", "") or review.get("review", "")).strip()

    def _predict_one(self, comment):
        prediction = self.pipeline.predict([comment])[0]
        confidence = None
        probabilities = {}

        if hasattr(self.pipeline, "predict_proba"):
            class_probabilities = self.pipeline.predict_proba([comment])[0]
            classes = self.pipeline.classes_
            probabilities = {
                str(label): float(probability)
                for label, probability in zip(classes, class_probabilities)
            }
            confidence = float(max(class_probabilities))

        return str(prediction), confidence, probabilities

    def analyze(self, reviews):
        if not isinstance(reviews, list) or len(reviews) == 0:
            raise ValueError("reviews must be a non-empty list")
        if self.pipeline is None:
            self.load_model(required=True)

        analyzed = []
        ratings = []
        words = []

        for review in reviews:
            comment = self._comment(review)
            if not comment:
                raise ValueError("each review must include comment or review text")

            sentiment, confidence, probabilities = self._predict_one(comment)
            rating = review.get("rating")
            if rating is not None and str(rating).strip() != "":
                ratings.append(float(rating))

            words.extend(
                word
                for word in self._tokens(comment)
                if word not in self.stopwords and len(word) > 3
            )

            analyzed.append(
                {
                    **review,
                    "sentiment": sentiment,
                    "confidence": confidence,
                    "probabilities": probabilities,
                    "model": self.model_path,
                }
            )

        sentiment_counts = Counter(item["sentiment"] for item in analyzed)
        common_terms = Counter(words).most_common(10)
        negative_reviews = [item for item in analyzed if item["sentiment"] == "negative"]

        insights = []
        if negative_reviews:
            insights.append(
                {
                    "type": "service_risk",
                    "message": "Negative reviews were detected and should be checked by admin.",
                    "count": len(negative_reviews),
                }
            )
        if ratings and sum(ratings) / len(ratings) < 3.5:
            insights.append(
                {
                    "type": "low_rating",
                    "message": "Average rating is below the healthy service threshold.",
                    "average_rating": sum(ratings) / len(ratings),
                }
            )

        return {
            "total_reviews": len(analyzed),
            "average_rating": (sum(ratings) / len(ratings)) if ratings else None,
            "sentiment_distribution": dict(sentiment_counts),
            "common_terms": [
                {"term": term, "count": count} for term, count in common_terms
            ],
            "insights": insights,
            "reviews": analyzed,
            "model": self.model_path,
            "model_metadata": self.metadata,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
