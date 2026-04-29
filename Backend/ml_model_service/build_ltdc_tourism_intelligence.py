import json
import os
import re
import sys
from pathlib import Path

import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.neighbors import NearestNeighbors


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
MODELS_DIR = BASE_DIR / "models"
EXTRACTED_TEXT_PATH = BASE_DIR / "extracted_text.json"

INTELLIGENCE_DATASET_PATH = DATA_DIR / "ltdc_tourism_intelligence.csv"
METRICS_DATASET_PATH = DATA_DIR / "ltdc_tourism_metrics.csv"
MODEL_PATH = MODELS_DIR / "ltdc_knowledge_model.pkl"


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def ensure_dirs():
    DATA_DIR.mkdir(exist_ok=True)
    MODELS_DIR.mkdir(exist_ok=True)


def normalize_spaces(value):
    text = str(value or "")
    text = text.replace("\n", " ")
    text = re.sub(r"\s+", " ", text)
    return text.strip(" ,;:-")


def clean_numeric_token(value):
    text = normalize_spaces(value).replace("%", "")
    text = text.replace(",", "")
    text = re.sub(r"(?<=\d)\.(?=\d{3}\b)", "", text)
    text = re.sub(r"[^0-9.\-]", "", text)
    if text in {"", ".", "-", "-.", ".-"}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def classify_topic(title, content):
    combined = f"{title} {content}".lower()
    if any(keyword in combined for keyword in ["arrival", "visitor arrivals", "country of residence"]):
        return "arrivals"
    if any(keyword in combined for keyword in ["accommodation", "hotel", "lodge", "guest nights", "occupancy"]):
        return "accommodation"
    if any(keyword in combined for keyword in ["perception", "satisfaction", "rating", "good service", "friendly"]):
        return "perception"
    if any(keyword in combined for keyword in ["attraction", "places visited", "activities"]):
        return "attractions"
    if any(keyword in combined for keyword in ["transport", "province", "country", "length of stay", "expenditure"]):
        return "visitor_profile"
    return "general_tourism"


def parse_report_metadata(filename):
    match = re.match(r"extracted_table_\d+_(.+)\.pdf_(\d+)\.csv", filename)
    if not match:
        return {"report_name": filename, "page": None, "year": None}

    report_name = match.group(1)
    page = int(match.group(2))
    year_match = re.search(r"(20\d{2}|2016-2017)", report_name)
    year = year_match.group(1) if year_match else None
    return {"report_name": report_name, "page": page, "year": year}


def load_table(path):
    df = pd.read_csv(path, dtype=str).fillna("")

    cleaned_columns = []
    for idx, col in enumerate(df.columns):
        col_text = normalize_spaces(col)
        if not col_text or col_text.lower().startswith("unnamed:"):
            col_text = f"column_{idx}"
        cleaned_columns.append(col_text)
    df.columns = cleaned_columns

    df = df.apply(lambda col: col.map(normalize_spaces))
    df = df.loc[:, df.apply(lambda col: col.ne("").any())]
    df = df[df.apply(lambda row: row.ne("").any(), axis=1)]
    df = df.reset_index(drop=True)
    return df


def infer_title(df):
    meaningful_columns = [col for col in df.columns if not col.startswith("column_")]
    for col in meaningful_columns:
        if len(col) > 2:
            return col

    if not df.empty:
        first_row = " ".join(value for value in df.iloc[0].tolist() if value)
        if len(first_row) > 3:
            return first_row[:160]

    return "Untitled LTDC table"


def row_to_text(row):
    values = [normalize_spaces(value) for value in row.tolist()]
    values = [value for value in values if value]
    return " | ".join(values)


def extract_metric_records(df, metadata, title):
    records = []
    for _, row in df.iterrows():
        values = [normalize_spaces(value) for value in row.tolist()]
        values = [value for value in values if value]
        if len(values) < 2:
            continue

        label = values[0]
        if len(label) < 2:
            continue

        heading_like_values = {"day trip", "1", "2", "3", "4", "5+", "total", "other"}
        normalized_values = {value.lower() for value in values[1:]}
        if label.lower() in {"purpose of visit", "country", "gender"}:
            continue
        if normalized_values and normalized_values.issubset(heading_like_values):
            continue

        numeric_values = [clean_numeric_token(value) for value in values[1:]]
        numeric_values = [value for value in numeric_values if value is not None]
        if not numeric_values:
            continue

        metric_text = f"{label}: {' | '.join(values[1:])}"
        records.append({
            **metadata,
            "table_title": title,
            "topic": classify_topic(title, metric_text),
            "metric_label": label,
            "metric_values_text": " | ".join(values[1:]),
            "primary_numeric_value": numeric_values[0],
            "numeric_value_count": len(numeric_values),
            "row_text": metric_text,
        })
    return records


def extract_knowledge_records():
    records = []
    metric_records = []

    for csv_path in sorted(BASE_DIR.glob("extracted_table_*.csv")):
        metadata = parse_report_metadata(csv_path.name)
        try:
            df = load_table(csv_path)
        except Exception:
            continue

        if df.empty:
            continue

        title = infer_title(df)
        row_texts = [row_to_text(row) for _, row in df.iterrows()]
        row_texts = [text for text in row_texts if text]
        if not row_texts:
            continue

        combined_text = "\n".join(row_texts)
        topic = classify_topic(title, combined_text)

        records.append({
            **metadata,
            "source_type": "table",
            "table_title": title,
            "topic": topic,
            "content": combined_text,
            "row_count": len(df),
            "column_count": len(df.columns),
            "record_key": f"{metadata['report_name']}|{metadata['page']}|{title}",
        })

        metric_records.extend(extract_metric_records(df, metadata, title))

    if EXTRACTED_TEXT_PATH.exists():
        with open(EXTRACTED_TEXT_PATH, "r", encoding="utf-8") as handle:
            extracted_text = json.load(handle)

        for item in extracted_text:
            content = normalize_spaces(item.get("content", ""))
            if len(content) < 120:
                continue

            report_name = item.get("filename", "unknown_report")
            year_match = re.search(r"(20\d{2}|2016-2017)", report_name)
            year = year_match.group(1) if year_match else None
            topic = classify_topic(report_name, content)

            records.append({
                "report_name": report_name,
                "page": None,
                "year": year,
                "source_type": "report_text",
                "table_title": report_name,
                "topic": topic,
                "content": content[:6000],
                "row_count": None,
                "column_count": None,
                "record_key": f"{report_name}|text",
            })

    intelligence_df = pd.DataFrame(records).drop_duplicates(subset=["record_key"]).reset_index(drop=True)
    metrics_df = pd.DataFrame(metric_records).drop_duplicates(
        subset=["report_name", "page", "table_title", "metric_label", "metric_values_text"]
    ).reset_index(drop=True)

    return intelligence_df, metrics_df


def train_knowledge_model(intelligence_df):
    corpus = (
        intelligence_df["report_name"].fillna("")
        + " "
        + intelligence_df["table_title"].fillna("")
        + " "
        + intelligence_df["topic"].fillna("")
        + " "
        + intelligence_df["content"].fillna("")
    )

    vectorizer = TfidfVectorizer(
        stop_words="english",
        ngram_range=(1, 2),
        min_df=1,
        max_features=12000,
    )
    matrix = vectorizer.fit_transform(corpus)

    model = NearestNeighbors(metric="cosine", algorithm="brute")
    model.fit(matrix)

    joblib.dump(
        {
            "vectorizer": vectorizer,
            "model": model,
            "records": intelligence_df.to_dict(orient="records"),
        },
        MODEL_PATH,
    )

    return matrix.shape


def main():
    ensure_dirs()
    print("=" * 70)
    print("LTDC TOURISM INTELLIGENCE PIPELINE")
    print("=" * 70)

    intelligence_df, metrics_df = extract_knowledge_records()
    intelligence_df.to_csv(INTELLIGENCE_DATASET_PATH, index=False)
    metrics_df.to_csv(METRICS_DATASET_PATH, index=False)

    matrix_shape = train_knowledge_model(intelligence_df)

    print(f"Knowledge records: {len(intelligence_df)}")
    print(f"Metric records: {len(metrics_df)}")
    print(f"Topics: {sorted(intelligence_df['topic'].dropna().unique().tolist())}")
    print(f"Vector matrix shape: {matrix_shape}")
    print(f"Saved dataset: {INTELLIGENCE_DATASET_PATH}")
    print(f"Saved metrics: {METRICS_DATASET_PATH}")
    print(f"Saved model: {MODEL_PATH}")
    print("=" * 70)
    print("LTDC tourism intelligence dataset extracted, cleaned, and trained successfully")
    print("=" * 70)


if __name__ == "__main__":
    main()
