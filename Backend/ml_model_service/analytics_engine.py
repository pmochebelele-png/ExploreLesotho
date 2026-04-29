# ml_model/analytics_engine.py
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from datetime import datetime, timedelta
import json
from collections import Counter

class AnalyticsEngine:
    def __init__(self):
        self.demand_forecaster = None
        self.segmenter = None
        self.scaler = StandardScaler()
        
    def train_demand_forecaster(self, booking_data):
        """Train demand forecasting model"""
        print("🔄 Training Demand Forecaster...")
        
        df = booking_data.copy()
        df['check_in'] = pd.to_datetime(df['check_in'])
        
        # Aggregate by date
        daily_demand = df.groupby(df['check_in'].dt.date).size().reset_index()
        daily_demand.columns = ['date', 'bookings']
        daily_demand['date'] = pd.to_datetime(daily_demand['date'])
        
        # Create time features
        daily_demand['dayofweek'] = daily_demand['date'].dt.dayofweek
        daily_demand['month'] = daily_demand['date'].dt.month
        daily_demand['week'] = daily_demand['date'].dt.isocalendar().week
        daily_demand['dayofyear'] = daily_demand['date'].dt.dayofyear
        
        # Lag features
        for lag in [1, 7, 14, 30]:
            daily_demand[f'lag_{lag}'] = daily_demand['bookings'].shift(lag)
        
        # Rolling statistics
        for window in [7, 14, 30]:
            daily_demand[f'rolling_mean_{window}'] = daily_demand['bookings'].rolling(window).mean()
            daily_demand[f'rolling_std_{window}'] = daily_demand['bookings'].rolling(window).std()
        
        # Drop NaN values
        daily_demand = daily_demand.dropna()
        
        # Prepare features
        feature_cols = [col for col in daily_demand.columns if col not in ['date', 'bookings']]
        X = daily_demand[feature_cols].values
        y = daily_demand['bookings'].values
        
        # Scale features
        X = self.scaler.fit_transform(X)
        
        # Train model
        self.demand_forecaster = RandomForestRegressor(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        self.demand_forecaster.fit(X, y)
        
        # Evaluate
        score = self.demand_forecaster.score(X, y)
        print(f"  R² Score: {score:.3f}")
        
        return self.demand_forecaster
    
    def predict_demand(self, days_ahead=30):
        """Predict future demand"""
        if self.demand_forecaster is None:
            raise ValueError("Demand forecaster not trained")
        
        predictions = []
        last_date = datetime.now()
        
        for i in range(days_ahead):
            pred_date = last_date + timedelta(days=i+1)
            
            # Create features for prediction
            features = {
                'dayofweek': pred_date.weekday(),
                'month': pred_date.month,
                'week': pred_date.isocalendar()[1],
                'dayofyear': pred_date.timetuple().tm_yday,
                'is_holiday': 1 if self._is_holiday(pred_date) else 0,
                'is_weekend': 1 if pred_date.weekday() >= 5 else 0,
            }
            
            # Use last known values for lags (simplified)
            for lag in [1, 7, 14, 30]:
                features[f'lag_{lag}'] = predictions[-lag] if len(predictions) >= lag else 50
            
            # Convert to array and predict
            X_pred = np.array([list(features.values())])
            X_pred = self.scaler.transform(X_pred)
            pred = self.demand_forecaster.predict(X_pred)[0]
            predictions.append(max(0, int(pred)))
        
        return predictions
    
    def analyze_sentiment(self, reviews_data):
        """Analyze review sentiment and extract insights"""
        df = pd.DataFrame(reviews_data)
        
        if len(df) == 0:
            return {}
        
        # Simple sentiment analysis (enhance with NLP)
        positive_keywords = ['good', 'great', 'excellent', 'amazing', 'wonderful', 
                            'beautiful', 'love', 'perfect', 'fantastic', 'best']
        negative_keywords = ['bad', 'poor', 'terrible', 'awful', 'disappointing', 
                            'worst', 'horrible', 'mediocre', 'boring', 'expensive']
        
        def get_sentiment(text):
            text_lower = str(text).lower()
            positive_count = sum(1 for word in positive_keywords if word in text_lower)
            negative_count = sum(1 for word in negative_keywords if word in text_lower)
            
            if positive_count > negative_count:
                return 'positive'
            elif negative_count > positive_count:
                return 'negative'
            else:
                return 'neutral'
        
        df['sentiment'] = df['comment'].apply(get_sentiment)
        df['rating_category'] = pd.cut(df['rating'], bins=[0, 2, 3.5, 5], 
                                       labels=['poor', 'average', 'good'])
        
        sentiment_counts = df['sentiment'].value_counts().to_dict()
        rating_distribution = df['rating_category'].value_counts().to_dict()
        
        # Extract common themes
        all_comments = ' '.join(df['comment'].astype(str))
        word_counts = Counter(all_comments.lower().split())
        
        # Remove common words
        stopwords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 
                    'for', 'of', 'with', 'by', 'was', 'were', 'is', 'are'}
        
        common_positive = []
        common_negative = []
        
        for word, count in word_counts.most_common(50):
            if word in stopwords or len(word) < 4:
                continue
            if any(p in word for p in positive_keywords):
                common_positive.append((word, count))
            elif any(n in word for n in negative_keywords):
                common_negative.append((word, count))
        
        return {
            'sentiment_distribution': sentiment_counts,
            'rating_distribution': rating_distribution,
            'positive_themes': common_positive[:10],
            'negative_themes': common_negative[:10],
            'average_rating': float(df['rating'].mean()),
            'total_reviews': len(df)
        }
    
    def segment_customers(self, user_data):
        """Segment customers based on behavior"""
        df = pd.DataFrame(user_data)
        
        if len(df) < 10:
            return {'segments': [], 'message': 'Insufficient data for segmentation'}
        
        # Create features for clustering
        features = df.groupby('user_id').agg({
            'total_bookings': 'sum',
            'total_spent': 'sum',
            'avg_rating': 'mean',
            'days_since_last_booking': 'mean'
        }).fillna(0)
        
        # Scale features
        scaled_features = StandardScaler().fit_transform(features)
        
        # Apply K-means clustering
        kmeans = KMeans(n_clusters=min(4, len(features)), random_state=42)
        clusters = kmeans.fit_predict(scaled_features)
        
        features['segment'] = clusters
        
        # Define segment profiles
        segment_profiles = {}
        for segment in range(kmeans.n_clusters):
            segment_data = features[features['segment'] == segment]
            
            if len(segment_data) > 0:
                avg_bookings = segment_data['total_bookings'].mean()
                avg_spent = segment_data['total_spent'].mean()
                
                if avg_bookings > 5 and avg_spent > 5000:
                    profile = 'Premium Traveler'
                elif avg_bookings > 2:
                    profile = 'Frequent Explorer'
                elif avg_spent > 2000:
                    profile = 'High Spender'
                else:
                    profile = 'Occasional Tourist'
                
                segment_profiles[segment] = {
                    'profile': profile,
                    'size': len(segment_data),
                    'avg_bookings': float(avg_bookings),
                    'avg_spent': float(avg_spent),
                    'percentage': (len(segment_data) / len(features)) * 100
                }
        
        return {
            'segments': segment_profiles,
            'total_customers': len(features)
        }
    
    def generate_insights(self, all_data):
        """Generate actionable insights for platform improvement"""
        insights = []
        
        # Extract data
        bookings = all_data.get('bookings', [])
        reviews = all_data.get('reviews', [])
        vendors = all_data.get('vendors', [])
        events = all_data.get('events', [])
        
        # Booking insights
        if len(bookings) > 0:
            df_bookings = pd.DataFrame(bookings)
            df_bookings['check_in'] = pd.to_datetime(df_bookings['check_in'])
            
            # Peak periods
            peak_months = df_bookings['check_in'].dt.month.value_counts().head(3).index.tolist()
            month_names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
            peak_seasons = [month_names[m-1] for m in peak_months]
            
            insights.append({
                'category': 'Demand',
                'title': 'Peak Booking Periods',
                'description': f"Highest demand occurs in {', '.join(peak_seasons)}",
                'recommendation': 'Increase marketing spend and prepare inventory 2 months before peak seasons',
                'priority': 'high',
                'impact': 'Increase revenue by 30-40%'
            })
            
            # Average lead time
            df_bookings['lead_days'] = (df_bookings['check_in'] - pd.to_datetime(df_bookings['created_at'])).dt.days
            avg_lead = df_bookings['lead_days'].mean()
            
            if avg_lead < 7:
                insights.append({
                    'category': 'Booking Behavior',
                    'title': 'Last-Minute Bookings High',
                    'description': f'Average booking lead time is only {avg_lead:.0f} days',
                    'recommendation': 'Implement flash sales and mobile push notifications for last-minute deals',
                    'priority': 'medium',
                    'impact': 'Capture 20% more spontaneous travelers'
                })
        
        # Review insights
        if len(reviews) > 0:
            df_reviews = pd.DataFrame(reviews)
            avg_rating = df_reviews['rating'].mean()
            
            if avg_rating < 4.0:
                insights.append({
                    'category': 'Quality',
                    'title': 'Ratings Below Target',
                    'description': f'Average rating is {avg_rating:.1f}/5.0',
                    'recommendation': 'Implement vendor training program and quality audits',
                    'priority': 'high',
                    'impact': 'Improve ratings to 4.5+ within 3 months'
                })
            
            # Low-rated categories
            low_rated = df_reviews.groupby('category')['rating'].mean().sort_values().head(2)
            if len(low_rated) > 0 and low_rated.iloc[0] < 4.0:
                insights.append({
                    'category': 'Quality',
                    'title': f'Poor Performance in {low_rated.index[0]}',
                    'description': f'{low_rated.index[0]} category has {low_rated.iloc[0]:.1f}⭐ average',
                    'recommendation': f'Review and improve {low_rated.index[0]} vendors, provide training',
                    'priority': 'high',
                    'impact': 'Increase customer satisfaction by 25%'
                })
        
        # Vendor insights
        if len(vendors) > 0:
            df_vendors = pd.DataFrame(vendors)
            active_vendors = df_vendors[df_vendors['is_active'] == True]
            
            if len(active_vendors) < len(df_vendors) * 0.7:
                insights.append({
                    'category': 'Vendor Management',
                    'title': 'Low Vendor Activity',
                    'description': f'Only {len(active_vendors)}/{len(df_vendors)} vendors are active',
                    'recommendation': 'Launch vendor incentive program and simplify onboarding',
                    'priority': 'medium',
                    'impact': 'Increase active vendors by 50%'
                })
        
        # Event insights
        if len(events) > 0:
            df_events = pd.DataFrame(events)
            upcoming = df_events[df_events['start_date'] > datetime.now()]
            
            if len(upcoming) < 3:
                insights.append({
                    'category': 'Events',
                    'title': 'Limited Upcoming Events',
                    'description': f'Only {len(upcoming)} events scheduled',
                    'recommendation': 'Partner with local organizers to create more events',
                    'priority': 'high',
                    'impact': 'Increase engagement by 40% during off-peak seasons'
                })
        
        # Revenue insights
        if len(bookings) > 0:
            total_revenue = df_bookings['grand_total'].sum()
            avg_booking = df_bookings['grand_total'].mean()
            
            insights.append({
                'category': 'Revenue',
                'title': 'Average Booking Value Analysis',
                'description': f'Average booking: M{avg_booking:.0f}, Total: M{total_revenue:,.0f}',
                'recommendation': 'Implement cross-selling and package deals to increase AOV',
                'priority': 'medium',
                'impact': 'Increase average booking value by 15-20%'
            })
        
        return insights
    
    def _is_holiday(self, date):
        """Check if date is a holiday (simplified)"""
        holidays = [
            (1, 1),   # New Year
            (3, 11),  # Moshoeshoe's Day
            (5, 1),   # Workers' Day
            (5, 25),  # Africa Day
            (7, 17),  # King's Birthday
            (10, 4),  # Independence Day
            (12, 25), # Christmas
            (12, 26)  # Boxing Day
        ]
        return (date.month, date.day) in holidays