import pandas as pd
import numpy as np
from datetime import datetime
import joblib
import os
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.model_selection import train_test_split
from pdf_verifier import PDFVerifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
import warnings
warnings.filterwarnings('ignore')

print("="*60)
print("🚀 Starting ML Model Training for Lesotho Tourism Platform")
print("="*60)

# Ensure models folder exists
os.makedirs("models", exist_ok=True)

# =========================================================
# 1. VENDOR VERIFIER
# =========================================================
class VendorVerifier:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoders = {}

    def generate_training_data(self):
        np.random.seed(42)
        data = []
        business_types = ['accommodation', 'tour_operator', 'restaurant', 'activity_provider']
        districts = ['Maseru', 'Leribe', 'Berea', 'Mafeteng', "Mohale's Hoek"]

        for i in range(2000):
            business_type = np.random.choice(business_types)
            district = np.random.choice(districts)
            has_license = np.random.choice([1, 0], p=[0.7, 0.3])
            license_valid = has_license * np.random.choice([1, 0], p=[0.9, 0.1])
            tax_clearance = np.random.choice([1, 0], p=[0.8, 0.2])
            previous_experience = np.random.randint(0, 20)
            rating = np.random.uniform(2, 5)

            approved = 1 if (
                has_license and license_valid and tax_clearance and
                (previous_experience >= 2 or rating >= 4)
            ) else 0

            data.append({
                'business_type': business_type,
                'district': district,
                'has_license': has_license,
                'license_valid': license_valid,
                'tax_clearance': tax_clearance,
                'previous_experience': previous_experience,
                'rating': rating,
                'approved': approved
            })

        return pd.DataFrame(data)

    def train(self):
        df = self.generate_training_data()

        for col in ['business_type', 'district']:
            self.label_encoders[col] = LabelEncoder()
            df[col + '_encoded'] = self.label_encoders[col].fit_transform(df[col])

        X = df[['business_type_encoded','district_encoded','has_license','license_valid','tax_clearance','previous_experience','rating']]
        y = df['approved']

        X = self.scaler.fit_transform(X)
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

        self.model = RandomForestClassifier(n_estimators=100)
        self.model.fit(X_train, y_train)

        print(f"  ✅ Vendor Model Accuracy: {self.model.score(X_test,y_test):.3f}")

    def save_model(self):
        joblib.dump({
            "model": self.model,
            "scaler": self.scaler,
            "label_encoders": self.label_encoders
        }, 'models/vendor_classifier.pkl')


# =========================================================
# 2. DEMAND FORECASTER
# =========================================================
class AnalyticsEngine:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()

    def train(self):
        dates = pd.date_range(end=datetime.now(), periods=365)
        bookings = np.random.randint(20,100,size=len(dates))

        df = pd.DataFrame({'date':dates,'bookings':bookings})
        df['month']=df['date'].dt.month

        X = df[['month']]
        y = df['bookings']

        X = self.scaler.fit_transform(X)
        self.model = RandomForestRegressor().fit(X,y)

        print("  ✅ Demand Model trained")


# =========================================================
# 3. TOURISM RECOMMENDER (FIXED)
# =========================================================
class TourismRecommender:
    def __init__(self):
        self.model = None
        self.encoder = LabelEncoder()
        self.data = None

    def load_data(self):
        print("\n📂 Loading culture dataset...")

        self.data = pd.read_csv("data/culture_combined.csv")

        # 🔥 CLEAN LOCATION
        self.data["location"] = self.data["location"].astype(str).str.strip()
        self.data["location"] = self.data["location"].str.lower()

        self.data["location"] = self.data["location"].replace(
            ["unknown", "", "ty"],
            "maseru"
        )

        self.data["location"] = self.data["location"].replace({
            "maseru": "Maseru"
        })

        # Fill missing
        self.data.fillna("Unknown", inplace=True)

        # Add fake ML features
        self.data["rating"] = 4.0

        print(f"  ✅ Loaded {len(self.data)} records")

    def train(self):
        print("\n🔄 Training Recommender Model...")

        self.data["location_encoded"] = self.encoder.fit_transform(self.data["location"])

        X = self.data[["location_encoded"]]
        y = np.random.randint(50,100,size=len(self.data))

        self.model = RandomForestRegressor()
        self.model.fit(X,y)

        joblib.dump(self.model, "models/recommender.pkl")

        print("  ✅ Recommender trained")

    def recommend(self, user):
        print("\n🎯 Generating recommendations...")

        location = user.get("location", "Maseru")

        if location not in self.encoder.classes_:
            location = "Maseru"

        encoded_loc = self.encoder.transform([location])[0]

        scores = self.model.predict([[encoded_loc]] * len(self.data))
        self.data["score"] = scores

        return self.data.sort_values("score", ascending=False).head(5)[
            ["name_and_surname","product_range","location","score"]
        ]

    def analytics(self):
        print("\n📊 Culture Analytics:")
        print(self.data["location"].value_counts().head())


# =========================================================
# MAIN
# =========================================================
if __name__ == "__main__":
    print("\n🤖 Training All Models\n")

    vendor = VendorVerifier()
    vendor.train()
    vendor.save_model()

    analytics = AnalyticsEngine()
    analytics.train()

    recommender = TourismRecommender()
    recommender.load_data()
    recommender.train()

    user = {"location": "Maseru"}
    recs = recommender.recommend(user)

    print("\n🎯 Top Recommendations:")
    print(recs)

    recommender.analytics()

    print("\n" + "="*60)
    print("✅ ALL MODELS TRAINED SUCCESSFULLY")
    print("="*60)