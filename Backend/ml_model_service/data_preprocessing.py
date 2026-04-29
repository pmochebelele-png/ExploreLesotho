# ml_model/data_preprocessing.py
import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder, StandardScaler
from datetime import datetime, timedelta
import json

class DataPreprocessor:
    def __init__(self):
        self.label_encoders = {}
        self.scaler = StandardScaler()
    
    def preprocess_vendor_data(self, df):
        """Preprocess vendor registration data for classification"""
        # Handle missing values
        df = df.fillna({
            'business_phone': 'unknown',
            'business_email': 'unknown',
            'tax_clearance': False,
            'previous_experience': 0,
            'rating': 0
        })
        
        # Encode categorical variables
        categorical_cols = ['business_type', 'district', 'has_license', 'license_valid']
        for col in categorical_cols:
            if col in df.columns:
                self.label_encoders[col] = LabelEncoder()
                df[col + '_encoded'] = self.label_encoders[col].fit_transform(df[col].astype(str))
        
        # Create features
        df['years_in_business'] = df.apply(
            lambda x: (datetime.now() - pd.to_datetime(x.get('registration_date', datetime.now()))).days // 365,
            axis=1
        )
        
        df['has_complete_documents'] = df.apply(
            lambda x: all([
                x.get('license_document') is not None,
                x.get('id_document') is not None,
                x.get('tax_clearance') == True
            ]), axis=1
        ).astype(int)
        
        # Select features for training
        feature_cols = [
            'business_type_encoded', 'district_encoded', 'has_license_encoded',
            'license_valid_encoded', 'years_in_business', 'has_complete_documents',
            'previous_experience', 'rating'
        ]
        
        feature_cols = [f for f in feature_cols if f in df.columns]
        
        X = df[feature_cols].values
        y = df['approved'].values if 'approved' in df.columns else None
        
        # Scale features
        if len(X) > 0:
            X = self.scaler.fit_transform(X)
        
        return X, y, feature_cols
    
    def preprocess_booking_data(self, df):
        """Preprocess booking data for demand forecasting"""
        df['check_in'] = pd.to_datetime(df['check_in'])
        df['check_out'] = pd.to_datetime(df['check_out'])
        df['booking_month'] = df['check_in'].dt.month
        df['booking_week'] = df['check_in'].dt.isocalendar().week
        df['booking_day'] = df['check_in'].dt.dayofweek
        df['stay_duration'] = (df['check_out'] - df['check_in']).dt.days
        
        # Seasonal features
        df['is_peak_season'] = df['booking_month'].isin([6, 7, 8, 12, 1, 2]).astype(int)
        df['is_weekend'] = df['booking_day'].isin([5, 6]).astype(int)
        
        return df

    def preprocess_review_data(self, df):
        """Preprocess review data for sentiment analysis"""
        # Extract text features
        df['review_length'] = df['comment'].str.len()
        df['has_positive_words'] = df['comment'].str.contains(
            'good|great|excellent|amazing|wonderful|beautiful|love', 
            case=False
        ).astype(int)
        df['has_negative_words'] = df['comment'].str.contains(
            'bad|poor|terrible|awful|disappointing|worst', 
            case=False
        ).astype(int)
        
        return df