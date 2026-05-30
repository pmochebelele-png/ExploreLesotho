
# data_cleaning/clean_data.py
import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler, LabelEncoder

class DataCleaner:
    def __init__(self, data):
        self.data = data
        self.scaler = MinMaxScaler()
        self.label_encoders = {}
    
    def clean_arrivals(self):
        """
        Clean arrivals data
        """
        df = self.data['arrivals'].copy()
        
        # Handle missing values
        df = df.fillna(method='ffill')
        
        # Remove outliers (if any)
        for col in ['total_arrivals', 'south_africa_pct']:
            Q1 = df[col].quantile(0.25)
            Q3 = df[col].quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            df[col] = df[col].clip(lower=lower_bound, upper=upper_bound)
        
        # Add derived features
        df['arrivals_growth'] = df['total_arrivals'].pct_change() * 100
        df['south_africa_growth'] = df['south_africa_pct'].pct_change() * 100
        
        return df
    
    def clean_monthly(self):
        """
        Clean monthly data
        """
        df = self.data['monthly'].copy()
        
        # Add seasonal features
        df['season'] = df['month'].apply(self._get_season)
        df['quarter'] = df['month'].apply(self._get_quarter)
        df['is_peak_month'] = df['arrivals_2024'] > df['arrivals_2024'].median()
        
        # Normalize arrivals
        arrivals_cols = ['arrivals_2024', 'arrivals_2023', 'arrivals_2022']
        df[arrivals_cols] = self.scaler.fit_transform(df[arrivals_cols])
        
        return df
    
    def clean_accommodation(self):
        """
        Clean accommodation data
        """
        df = self.data['accommodation'].copy()
        
        # Add derived features
        df['rooms_per_establishment'] = df['rooms'] / df['establishments']
        df['beds_per_room'] = df['beds'] / df['rooms']
        df['revenue_per_room'] = df['revenue_millions'] * 1000000 / df['rooms']
        df['revenue_per_employee'] = df['revenue_millions'] * 1000000 / df['employees']
        
        # Add occupancy trends
        df['occupancy_growth'] = df['bed_occupancy_rate'].pct_change() * 100
        
        return df
    
    def clean_accommodation_by_type(self):
        """
        Clean accommodation by type data
        """
        df = self.data['accommodation_by_type'].copy()
        
        # Encode establishment types
        le = LabelEncoder()
        df['type_encoded'] = le.fit_transform(df['establishment_type'])
        self.label_encoders['establishment_type'] = le
        
        # Calculate market share
        total_rooms_2024 = df['rooms_2024'].sum()
        df['rooms_share_2024'] = df['rooms_2024'] / total_rooms_2024 * 100
        
        return df
    
    def clean_attractions(self):
        """
        Clean attractions data
        """
        df = self.data['attractions'].copy()
        
        # Encode attraction names
        le = LabelEncoder()
        df['attraction_encoded'] = le.fit_transform(df['attraction'])
        self.label_encoders['attraction'] = le
        
        # Create visitor segments
        df['domestic_visitors'] = df['total_visitors_2023'] * df['domestic_pct'] / 100
        df['international_visitors'] = df['total_visitors_2023'] * df['international_pct'] / 100
        df['school_visitors'] = df['total_visitors_2023'] * df['school_children_pct'] / 100
        df['general_visitors'] = df['total_visitors_2023'] * df['general_public_pct'] / 100
        
        return df
    
    def clean_sentiment(self):
        """
        Clean sentiment/perception data
        """
        df = self.data['perceptions'].copy()
        
        # Encode sentiment categories
        le = LabelEncoder()
        df['sentiment_encoded'] = le.fit_transform(df['sentiment_category'])
        self.label_encoders['sentiment'] = le
        
        df['type_encoded'] = le.fit_transform(df['type'])
        
        # Add cumulative percentages
        df = df.sort_values('percentage', ascending=False)
        df['cumulative_percentage'] = df['percentage'].cumsum()
        
        return df
    
    def clean_expenditure(self):
        """
        Clean expenditure data
        """
        df = self.data['expenditure'].copy()
        
        # Encode countries
        le = LabelEncoder()
        df['country_encoded'] = le.fit_transform(df['country'])
        self.label_encoders['country'] = le
        
        # Calculate spending ratios
        spending_cols = ['accommodation_spend', 'food_spend', 'transport_spend', 
                         'entertainment_spend', 'shopping_spend']
        
        for col in spending_cols:
            df[f'{col}_ratio'] = df[col] / df['avg_spend_per_night']
        
        return df
    
    def clean_visitor_profiles(self):
        """
        Clean visitor profile data
        """
        df = self.data['visitor_profiles'].copy()
        
        # Calculate total per age group
        age_groups = df['age_group'].values
        male_cols = ['male_leisure', 'male_vfr', 'male_business']
        female_cols = ['female_leisure', 'female_vfr', 'female_business']
        
        df['male_total'] = df[male_cols].sum(axis=1)
        df['female_total'] = df[female_cols].sum(axis=1)
        df['total_visitors'] = df['male_total'] + df['female_total']
        
        # Calculate proportions
        for col in male_cols + female_cols:
            df[f'{col}_pct'] = df[col] / df['total_visitors'] * 100
        
        return df
    
    def clean_origin(self):
        """
        Clean origin data
        """
        df = self.data['origin'].copy()
        
        # Encode countries
        le = LabelEncoder()
        df['country_encoded'] = le.fit_transform(df['country'])
        self.label_encoders['origin_country'] = le
        
        # Calculate market share
        total_arrivals_2024 = df['arrivals_2024'].sum()
        df['market_share_2024'] = df['arrivals_2024'] / total_arrivals_2024 * 100
        
        # Add growth categories
        df['growth_category'] = pd.cut(df['growth_pct'], 
                                       bins=[0, 20, 50, 100, 200],
                                       labels=['Low', 'Medium', 'High', 'Very High'])
        
        return df
    
    def clean_all(self):
        """
        Clean all datasets
        """
        print("Cleaning arrivals data...")
        arrivals = self.clean_arrivals()
        
        print("Cleaning monthly data...")
        monthly = self.clean_monthly()
        
        print("Cleaning accommodation data...")
        accommodation = self.clean_accommodation()
        accommodation_by_type = self.clean_accommodation_by_type()
        accommodation_by_district = self.data['accommodation_by_district'].copy()
        
        print("Cleaning attractions data...")
        attractions = self.clean_attractions()
        
        print("Cleaning sentiment data...")
        perceptions = self.clean_sentiment()
        
        print("Cleaning expenditure data...")
        expenditure = self.clean_expenditure()
        
        print("Cleaning visitor profiles...")
        visitor_profiles = self.clean_visitor_profiles()
        
        print("Cleaning origin data...")
        origin = self.clean_origin()
        
        return {
            'arrivals': arrivals,
            'monthly': monthly,
            'accommodation': accommodation,
            'accommodation_by_type': accommodation_by_type,
            'accommodation_by_district': accommodation_by_district,
            'attractions': attractions,
            'perceptions': perceptions,
            'expenditure': expenditure,
            'visitor_profiles': visitor_profiles,
            'origin': origin
        }
    
    def _get_season(self, month):
        """
        Get season based on month
        """
        if month in [12, 1, 2]:
            return 'Summer'
        elif month in [3, 4, 5]:
            return 'Autumn'
        elif month in [6, 7, 8]:
            return 'Winter'
        else:
            return 'Spring'
    
    def _get_quarter(self, month):
        """
        Get quarter based on month
        """
        if month in [1, 2, 3]:
            return 'Q1'
        elif month in [4, 5, 6]:
            return 'Q2'
        elif month in [7, 8, 9]:
            return 'Q3'
        else:
            return 'Q4'

# Run cleaning
if __name__ == "__main__":
    from data_extraction.extract_all_data import DataExtractor
    
    # Extract data
    extractor = DataExtractor('data/raw')
    raw_data = extractor.extract_all()
    
    # Clean data
    cleaner = DataCleaner(raw_data)
    cleaned_data = cleaner.clean_all()
    
    # Save cleaned data
    for name, df in cleaned_data.items():
        df.to_csv(f'data/cleaned/{name}_cleaned.csv', index=False)
        print(f"Saved cleaned {name}.csv")