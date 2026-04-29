# ml_model/train_review_sentiment.py

import argparse
import os

import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline


VALID_SENTIMENTS = {"negative", "neutral", "positive"}


def load_reviews(path):
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"{path} not found. Export real reviews with comment/review and sentiment columns first."
        )

    df = pd.read_csv(path)
    text_column = "comment" if "comment" in df.columns else "review" if "review" in df.columns else None
    if text_column is None:
        raise ValueError("Dataset must contain a comment or review column.")
    if "sentiment" not in df.columns:
        raise ValueError(
            "Dataset must contain a sentiment column with labels: negative, neutral, positive."
        )

    df = df[[text_column, "sentiment"]].dropna()
    df.columns = ["text", "sentiment"]
    df["text"] = df["text"].astype(str).str.strip()
    df["sentiment"] = df["sentiment"].astype(str).str.strip().str.lower()
    df = df[(df["text"] != "") & (df["sentiment"].isin(VALID_SENTIMENTS))]

    if len(df) < 30:
        raise ValueError(
            f"Need at least 30 real labeled reviews to train responsibly. Found {len(df)}."
        )
    if df["sentiment"].nunique() < 2:
        raise ValueError("Need at least two sentiment classes to train a classifier.")

    return df


def train(input_path, output_path):
    df = load_reviews(input_path)
    label_counts = df["sentiment"].value_counts().to_dict()
    stratify = df["sentiment"] if df["sentiment"].value_counts().min() >= 2 else None

    X_train, X_test, y_train, y_test = train_test_split(
        df["text"],
        df["sentiment"],
        test_size=0.2,
        random_state=42,
        stratify=stratify,
    )

    pipeline = Pipeline(
        [
            (
                "tfidf",
                TfidfVectorizer(
                    lowercase=True,
                    ngram_range=(1, 2),
                    min_df=1,
                    max_features=5000,
                ),
            ),
            (
                "classifier",
                LogisticRegression(
                    max_iter=1000,
                    class_weight="balanced",
                    random_state=42,
                ),
            ),
        ]
    )
    pipeline.fit(X_train, y_train)

    predictions = pipeline.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    report = classification_report(y_test, predictions, output_dict=True, zero_division=0)

    metadata = {
        "algorithm": "TfidfVectorizer + LogisticRegression",
        "input_path": input_path,
        "rows": int(len(df)),
        "train_rows": int(len(X_train)),
        "test_rows": int(len(X_test)),
        "label_counts": {str(k): int(v) for k, v in label_counts.items()},
        "accuracy": float(accuracy),
        "classification_report": report,
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    joblib.dump({"pipeline": pipeline, "metadata": metadata}, output_path)

    print("=" * 60)
    print("Review Sentiment Model Trained")
    print("=" * 60)
    print(f"Input: {input_path}")
    print(f"Saved: {output_path}")
    print(f"Rows: {len(df)}")
    print(f"Accuracy: {accuracy:.3f}")
    print(f"Labels: {metadata['label_counts']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train scikit-learn review sentiment model.")
    parser.add_argument(
        "--input",
        default="data/review_sentiment_dataset.csv",
        help="CSV with comment/review and sentiment columns.",
    )
    parser.add_argument(
        "--output",
        default="models/review_sentiment_model.pkl",
        help="Output model artifact path.",
    )
    args = parser.parse_args()
    train(args.input, args.output)
