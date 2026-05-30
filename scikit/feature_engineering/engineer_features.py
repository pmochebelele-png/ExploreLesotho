
# feature_engineering/engineer_features.py
import pandas as pd
import numpy as np
from datetime import datetime

class FeatureEngineer:
    def __init__(self, cleaned_data):
        self.data = cleaned_data
    
    def create_time_features(self, df):
        """
        Create time-based features for predictions
        """
        if 'month' in df.columns:
            df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
            df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)
        
        if 'year' in df.columns:
            df['year_since_2020'] = df['year'] - 2020
        
        return df
    
    def create_lag_features(self, df, col, lags=[1, 2, 3]):
        """
        Create lag features for time series
        """
        for lag in lags:
            df[f'{col}_lag_{lag}'] = df[col].shift(lag)
        
        return df
    
    def create_rolling_features(self, df, col, windows=[3, 6, 12]):
        """
        Create rolling window features
        """
        for window in windows:
            df[f'{col}_rolling_mean_{window}'] = df[col].rolling(window=window).mean()
            df[f'{col}_rolling_std_{window}'] = df[col].rolling(window=window).std()
        
        return df
    
    def create_interaction_features(self):
        """
        Create interaction features between datasets
        """
        # Combine arrivals with accommodation
        arrivals = self.data['arrivals']
        accommodation = self.data['accommodation']
        
        merged = pd.merge(arrivals, accommodation, on='year', how='inner')
        
        # Interaction features
        merged['arrivals_per_room'] = merged['total_arrivals'] / merged['rooms']
        merged['revenue_per_arrival'] = merged['revenue_millions'] * 1000000 / merged['total_arrivals']
        
        return merged
    
    def create_attraction_features(self):
        """
        Create attraction-specific features
        """
        attractions = self.data['attractions'].copy()
        
        # Normalize visitor counts
        max_visitors = attractions['total_visitors_2023'].max()
        attractions['normalized_visitors'] = attractions['total_visitors_2023'] / max_visitors
        
        # Create visitor mix features
        attractions['domestic_ratio'] = attractions['domestic_pct'] / 100
        attractions['international_ratio'] = attractions['international_pct'] / 100
        
        # School vs general ratio
        attractions['school_to_general_ratio'] = attractions['school_children_pct'] / attractions['general_public_pct']
        
        return attractions
    
    def create_sentiment_features(self):
        """
        Create sentiment-based features
        """
        perceptions = self.data['perceptions'].copy()
        
        # Group by type
        service_sentiment = perceptions[perceptions['type'] == 'Service']['percentage'].sum()
        people_sentiment = perceptions[perceptions['type'] == 'People']['percentage'].sum()
        scenery_sentiment = perceptions[perceptions['type'] == 'Scenery']['percentage'].sum()
        culture_sentiment = perceptions[perceptions['type'] == 'Culture']['percentage'].sum()
        
        # Calculate overall sentiment score
        weighted_sentiment = (
            service_sentiment * 0.3 +
            people_sentiment * 0.25 +
            scenery_sentiment * 0.25 +
            culture_sentiment * 0.2
        )
        
        return {
            'service_sentiment': service_sentiment,
            'people_sentiment': people_sentiment,
            'scenery_sentiment': scenery_sentiment,
            'culture_sentiment': culture_sentiment,
            'overall_sentiment_score': weighted_sentiment
        }
    
    def create_origin_features(self):
        """
        Create origin-based features for recommendations
        """
        origin = self.data['origin'].copy()
        
        # Calculate growth potential
        origin['growth_potential'] = origin['growth_pct'] / 100
        
        # Create country clusters based on behavior
        origin['high_growth_market'] = (origin['growth_pct'] > 50).astype(int)
        
        return origin
    
    def engineer_all_features(self):
        """
        Create all engineered features
        """
        print("Creating time features...")
        monthly = self.create_time_features(self.data['monthly'])
        monthly = self.create_lag_features(monthly, 'arrivals_2024')
        monthly = self.create_rolling_features(monthly, 'arrivals_2024')
        
        print("Creating interaction features...")
        interaction = self.create_interaction_features()
        
        print("Creating attraction features...")
        attraction_features = self.create_attraction_features()
        
        print("Creating sentiment features...")
        sentiment_features = self.create_sentiment_features()
        
        print("Creating origin features...")
        origin_features = self.create_origin_features()
        
        return {
            'monthly_features': monthly,
            'interaction_features': interaction,
            'attraction_features': attraction_features,
            'sentiment_features': sentiment_features,
            'origin_features': origin_features
        }

# Run feature engineering
if __name__ == "__main__":
    import pandas as pd
    from data_cleaning.clean_data import DataCleaner
    from data_extraction.extract_all_data import DataExtractor
    
    # Load cleaned data (or run extraction and cleaning)
    cleaned_data = {}
    data_names = ['arrivals', 'monthly', 'accommodation', 'accommodation_by_type',
                  'accommodation_by_district', 'attractions', 'perceptions', 
                  'expenditure', 'visitor_profiles', 'origin']
    
    for name in data_names:
        try:
            cleaned_data[name] = pd.read_csv(f'data/cleaned/{name}_cleaned.csv')
        except:
            print(f"Could not load {name}_cleaned.csv, running extraction and cleaning...")
            extractor = DataExtractor('data/raw')
            raw_data = extractor.extract_all()
            cleaner = DataCleaner(raw_data)
            cleaned_data = cleaner.clean_all()
            break
    
    # Engineer features
    engineer = FeatureEngineer(cleaned_data)
    features = engineer.engineer_all_features()
    
    # Save features
    for name, df in features.items():
        if isinstance(df, pd.DataFrame):
            df.to_csv(f'data/features/{name}.csv', index=False)
        else:
            # Save as JSON for non-DataFrame features
            import json
            with open(f'data/features/{name}.json', 'w') as f:
                json.dump(df, f, indent=2)
        
        print(f"Saved {name} features")