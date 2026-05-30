# run_tourism.py - Complete Tourism Data Processing
import pandas as pd
import numpy as np
import os

print("=" * 70)
print("TOURISM DATA PROCESSING")
print("=" * 70)

# Create Dataset folder
if not os.path.exists('Dataset'):
    os.makedirs('Dataset')
    print("✓ Created Dataset folder")

# ============================================
# CREATE ALL DATASETS
# ============================================
print("\n📊 Creating datasets...")

# 1. Annual Arrivals
arrivals = pd.DataFrame({
    'year': [2022, 2023, 2024],
    'total_arrivals': [541134, 733694, 960361],
    'south_africa_pct': [90.5, 89.6, 89.6],
    'male_pct': [62.4, 58.0, 58.0],
    'female_pct': [37.6, 42.0, 42.0],
    'leisure_pct': [70.8, 70.8, 74.3]
})
arrivals.to_csv('Dataset/arrivals.csv', index=False)
print("  ✓ arrivals.csv")

# 2. Monthly Patterns
monthly = pd.DataFrame({
    'month': list(range(1, 13)),
    'month_name': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    'arrivals': [55622, 47710, 60035, 70793, 53753, 55297,
                 57651, 58663, 56348, 59626, 58643, 99553],
    'revenue': [8.6, 7.6, 7.6, 7.9, 9.4, 8.4, 8.0, 8.0, 7.7, 7.6, 16.6, 7.6]
})
monthly.to_csv('Dataset/monthly.csv', index=False)
print("  ✓ monthly.csv")

# 3. Accommodation
accommodation = pd.DataFrame({
    'year': [2022, 2023, 2024],
    'rooms': [3567, 3598, 3650],
    'occupancy_rate': [18.3, 19.9, 23.6],
    'revenue_millions': [349.9, 450.9, 542.0],
    'employees': [2252, 1887, 2226]
})
accommodation.to_csv('Dataset/accommodation.csv', index=False)
print("  ✓ accommodation.csv")

# 4. Attractions
attractions = pd.DataFrame({
    'attraction': ['Thaba Bosiu', 'Morija Museum', 'Maletsunyane Falls', 'Kome Caves'],
    'visitors': [32097, 14351, 9850, 3034],
    'domestic_pct': [96.4, 96.1, 78.6, 79.0],
    'international_pct': [3.6, 3.9, 21.4, 21.0]
})
attractions.to_csv('Dataset/attractions.csv', index=False)
print("  ✓ attractions.csv")

# 5. Visitor Perceptions
perceptions = pd.DataFrame({
    'sentiment': ['Good Service', 'Friendly', 'Fantastic', 'Great', 
                 'Helpful', 'Beautiful', 'Interesting', 'Poor Signage'],
    'percentage': [37.1, 12.7, 10.4, 8.8, 8.8, 8.7, 5.9, 0.4],
    'category': ['Service', 'People', 'Overall', 'Overall', 'Service', 
                'Scenery', 'Culture', 'Infrastructure']
})
perceptions.to_csv('Dataset/perceptions.csv', index=False)
print("  ✓ perceptions.csv")

# 6. Visitor Spending
spending = pd.DataFrame({
    'country': ['South Africa', 'Netherlands', 'Germany', 'UK', 'USA'],
    'spend_per_night': [839, 1019, 896, 1193, 982],
    'accommodation_pct': [48.4, 51.1, 53.5, 51.1, 49.2],
    'food_pct': [22.4, 21.2, 23.6, 22.9, 22.8]
})
spending.to_csv('Dataset/spending.csv', index=False)
print("  ✓ spending.csv")

# 7. Visitor Origins
origin = pd.DataFrame({
    'country': ['South Africa', 'Zimbabwe', 'USA', 'India', 'Netherlands', 'China', 'Germany', 'UK'],
    'arrivals_2024': [860000, 19200, 6720, 5760, 5760, 5760, 3840, 3840],
    'growth_pct': [31.0, 34.5, 52.8, 19.5, 161.6, 33.2, 36.8, 31.9]
})
origin.to_csv('Dataset/origin.csv', index=False)
print("  ✓ origin.csv")

# ============================================
# CLEAN DATA
# ============================================
print("\n🧹 Cleaning data...")

# Clean arrivals
arrivals_clean = arrivals.copy()
arrivals_clean['growth'] = arrivals_clean['total_arrivals'].pct_change() * 100
arrivals_clean['growth'] = arrivals_clean['growth'].fillna(0)
arrivals_clean.to_csv('Dataset/arrivals_cleaned.csv', index=False)
print("  ✓ arrivals_cleaned.csv")

# Clean monthly
monthly_clean = monthly.copy()
def get_season(m):
    if m in [12, 1, 2]: return 'Summer'
    elif m in [3, 4, 5]: return 'Autumn'
    elif m in [6, 7, 8]: return 'Winter'
    else: return 'Spring'
monthly_clean['season'] = monthly_clean['month'].apply(get_season)
monthly_clean['quarter'] = monthly_clean['month'].apply(lambda x: f'Q{(x-1)//3+1}')
monthly_clean['is_peak'] = monthly_clean['arrivals'] > monthly_clean['arrivals'].median()
monthly_clean.to_csv('Dataset/monthly_cleaned.csv', index=False)
print("  ✓ monthly_cleaned.csv")

# Clean accommodation
accommodation_clean = accommodation.copy()
accommodation_clean['revenue_per_room'] = accommodation_clean['revenue_millions'] * 1e6 / accommodation_clean['rooms']
accommodation_clean['occupancy_growth'] = accommodation_clean['occupancy_rate'].pct_change() * 100
accommodation_clean['occupancy_growth'] = accommodation_clean['occupancy_growth'].fillna(0)
accommodation_clean.to_csv('Dataset/accommodation_cleaned.csv', index=False)
print("  ✓ accommodation_cleaned.csv")

# Clean attractions
attractions_clean = attractions.copy()
attractions_clean['domestic_visitors'] = attractions_clean['visitors'] * attractions_clean['domestic_pct'] / 100
attractions_clean['international_visitors'] = attractions_clean['visitors'] * attractions_clean['international_pct'] / 100
attractions_clean['popularity'] = attractions_clean['visitors'] / attractions_clean['visitors'].max()
attractions_clean.to_csv('Dataset/attractions_cleaned.csv', index=False)
print("  ✓ attractions_cleaned.csv")

# Clean perceptions
perceptions_clean = perceptions.copy()
perceptions_clean = perceptions_clean.sort_values('percentage', ascending=False)
perceptions_clean['cumulative'] = perceptions_clean['percentage'].cumsum()
perceptions_clean.to_csv('Dataset/perceptions_cleaned.csv', index=False)
print("  ✓ perceptions_cleaned.csv")

# Clean spending
spending_clean = spending.copy()
spending_clean['accommodation_spend'] = spending_clean['spend_per_night'] * spending_clean['accommodation_pct'] / 100
spending_clean['food_spend'] = spending_clean['spend_per_night'] * spending_clean['food_pct'] / 100
spending_clean.to_csv('Dataset/spending_cleaned.csv', index=False)
print("  ✓ spending_cleaned.csv")

# Clean origin
origin_clean = origin.copy()
total = origin_clean['arrivals_2024'].sum()
origin_clean['market_share'] = (origin_clean['arrivals_2024'] / total) * 100
origin_clean.to_csv('Dataset/origin_cleaned.csv', index=False)
print("  ✓ origin_cleaned.csv")

# ============================================
# CREATE FEATURES
# ============================================
print("\n🔧 Creating features...")

# Time features
time_features = monthly_clean.copy()
time_features['month_sin'] = np.sin(2 * np.pi * time_features['month'] / 12)
time_features['month_cos'] = np.cos(2 * np.pi * time_features['month'] / 12)
time_features['lag_1'] = time_features['arrivals'].shift(1)
time_features['rolling_3'] = time_features['arrivals'].rolling(window=3).mean()
# FIXED: Use bfill() instead of fillna(method='bfill')
time_features = time_features.bfill()
time_features.to_csv('Dataset/features_time.csv', index=False)
print("  ✓ features_time.csv")

# Attraction features
attraction_features = attractions_clean.copy()
attraction_features['recommendation_score'] = attraction_features['popularity'] * 100
attraction_features.to_csv('Dataset/features_attractions.csv', index=False)
print("  ✓ features_attractions.csv")

# Sentiment features
sentiment_by_type = perceptions_clean.groupby('category')['percentage'].sum().reset_index()
sentiment_by_type.columns = ['category', 'sentiment_score']
sentiment_by_type.to_csv('Dataset/features_sentiment.csv', index=False)
print("  ✓ features_sentiment.csv")

# ============================================
# SUMMARY
# ============================================
print("\n" + "=" * 70)
print("✅ PROCESSING COMPLETE!")
print("=" * 70)

print("\n📁 FILES CREATED IN Dataset folder:")
print("-" * 50)

files = [
    "arrivals.csv", "monthly.csv", "accommodation.csv", "attractions.csv",
    "perceptions.csv", "spending.csv", "origin.csv",
    "arrivals_cleaned.csv", "monthly_cleaned.csv", "accommodation_cleaned.csv",
    "attractions_cleaned.csv", "perceptions_cleaned.csv", "spending_cleaned.csv",
    "origin_cleaned.csv", "features_time.csv", "features_attractions.csv",
    "features_sentiment.csv"
]

for file in files:
    filepath = f"Dataset/{file}"
    if os.path.exists(filepath):
        df = pd.read_csv(filepath)
        print(f"  ✓ {file:<30} ({df.shape[0]} rows, {df.shape[1]} cols)")

print(f"\n📂 Location: C:\\Users\\SUBLIME TECHNOLOGIES\\Downloads\\scikit\\Dataset\\")
print("\n💡 You can now open these CSV files in Excel!")