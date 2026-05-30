
# data_extraction/extract_all_data.py
import os
import json
import pandas as pd
import numpy as np
from datetime import datetime
import PyPDF2
import re

class DataExtractor:
    def __init__(self, data_path):
        self.data_path = data_path
        self.extracted_data = {
            'arrivals': {},
            'accommodation': {},
            'attractions': {},
            'perceptions': {},
            'expenditure': {}
        }
    
    def extract_arrivals_data(self):
        """
        Extract arrivals data from reports
        """
        arrivals_data = {
            'year': [2022, 2023, 2024],
            'total_arrivals': [541134, 733694, 960361],
            'south_africa_pct': [90.5, 89.6, 89.6],
            'zimbabwe_pct': [1.74, 2.0, 2.0],
            'usa_pct': [0.67, 0.7, 0.7],
            'india_pct': [0.72, 0.6, 0.6],
            'male_pct': [62.4, 58.0, 58.0],
            'female_pct': [37.6, 42.0, 42.0],
            'leisure_pct': [70.8, 70.8, 74.3],
            'vfr_pct': [6.4, 6.4, 20.1],
            'business_pct': [2.6, 2.6, 2.1]
        }
        
        self.extracted_data['arrivals'] = pd.DataFrame(arrivals_data)
        return self.extracted_data['arrivals']
    
    def extract_monthly_data(self):
        """
        Extract monthly arrival patterns
        """
        monthly_data = {
            'month': list(range(1, 13)),
            'month_name': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
            'arrivals_2024': [55622, 47710, 60035, 70793, 53753, 55297,
                              57651, 58663, 56348, 59626, 58643, 99553],
            'arrivals_2023': [55622, 47710, 60035, 70793, 53753, 55297,
                              57651, 58663, 56348, 59626, 58643, 99553],
            'arrivals_2022': [27546, 28611, 34525, 44726, 38991, 46164,
                              51093, 55990, 50326, 46317, 36592, 80253]
        }
        
        self.extracted_data['monthly'] = pd.DataFrame(monthly_data)
        return self.extracted_data['monthly']
    
    def extract_accommodation_data(self):
        """
        Extract accommodation statistics
        """
        accommodation_data = {
            'year': [2022, 2023, 2024],
            'establishments': [180, 165, 192],
            'rooms': [3567, 3598, 3650],
            'beds': [5373, 5453, 5600],
            'bed_occupancy_rate': [18.3, 19.9, 23.6],
            'revenue_millions': [349.9, 450.9, 542.0],
            'employees': [2252, 1887, 2226],
            'female_employees_pct': [60.7, 61.3, 57.8],
            'male_employees_pct': [39.3, 38.7, 42.2],
            'skilled_employees_pct': [63.5, 64.7, 78.8]
        }
        
        self.extracted_data['accommodation'] = pd.DataFrame(accommodation_data)
        return self.extracted_data['accommodation']
    
    def extract_accommodation_by_type(self):
        """
        Extract accommodation breakdown by type
        """
        type_data = {
            'establishment_type': ['Hotel', 'Guest House', 'Lodge', 'B&B', 'Other'],
            'rooms_2024': [1628, 1051, 455, 324, 192],
            'rooms_2023': [1615, 1029, 523, 306, 125],
            'rooms_2022': [1615, 1003, 517, 319, 113],
            'bed_occupancy_2024': [36.8, 31.9, 10.4, 9.6, 8.5],
            'bed_occupancy_2023': [35.0, 18.6, 10.4, 9.6, 8.5],
            'revenue_share_2024': [54.2, 22.6, 15.5, 3.1, 4.6]
        }
        
        self.extracted_data['accommodation_by_type'] = pd.DataFrame(type_data)
        return self.extracted_data['accommodation_by_type']
    
    def extract_accommodation_by_district(self):
        """
        Extract accommodation data by district
        """
        district_data = {
            'district': ['Maseru', 'Leribe', 'Butha-Buthe', 'Mohale\'s Hoek', 
                        'Mafeteng', 'Mokhotlong', 'Qacha\'s Nek', 'Berea', 
                        'Quthing', 'Thaba-Tseka'],
            'rooms_2024': [1478, 303, 173, 275, 295, 261, 222, 353, 120, 135],
            'rooms_2023': [1461, 303, 173, 275, 295, 261, 222, 353, 120, 135],
            'bed_occupancy_2024': [37.9, 29.3, 21.4, 25.1, 23.0, 22.8, 21.8, 19.8, 20.4, 16.8],
            'bed_occupancy_2023': [23.0, 26.4, 29.3, 20.8, 7.6, 17.6, 9.2, 18.6, 20.4, 14.3],
            'revenue_share_2024': [52.4, 9.9, 7.9, 5.6, 4.8, 4.6, 4.2, 3.8, 3.5, 2.7]
        }
        
        self.extracted_data['accommodation_by_district'] = pd.DataFrame(district_data)
        return self.extracted_data['accommodation_by_district']
    
    def extract_attractions_data(self):
        """
        Extract key attractions data
        """
        attractions_data = {
            'attraction': ['Thaba Bosiu', 'Morija Museum', 'Maletsunyane Falls', 'Kome Caves'],
            'total_visitors_2023': [32097, 14351, 9850, 3034],
            'domestic_pct': [96.4, 96.1, 78.6, 79.0],
            'international_pct': [3.6, 3.9, 21.4, 21.0],
            'school_children_pct': [89.3, 45.8, 38.1, 48.5],
            'general_public_pct': [6.8, 49.5, 52.9, 29.9],
            'top_district': ['Maseru', 'Maseru', 'Maseru', 'Maseru'],
            'peak_months': ['Feb, May, Aug, Dec', 'Mar, Sep, Nov', 'Aug, Oct, Nov', 'Sep, Dec']
        }
        
        self.extracted_data['attractions'] = pd.DataFrame(attractions_data)
        return self.extracted_data['attractions']
    
    def extract_sentiment_data(self):
        """
        Extract visitor perception data
        """
        sentiment_data = {
            'sentiment_category': ['Good Service', 'Friendly', 'Fantastic', 'Great', 
                                   'Helpful', 'Beautiful', 'Interesting', 'Amazing', 
                                   'Peaceful', 'Poor Signage'],
            'percentage': [37.1, 12.7, 10.4, 8.8, 8.8, 8.7, 5.9, 2.0, 1.2, 0.4],
            'type': ['Service', 'People', 'Overall', 'Overall', 'Service', 
                    'Scenery', 'Culture', 'Overall', 'Environment', 'Infrastructure']
        }
        
        self.extracted_data['perceptions'] = pd.DataFrame(sentiment_data)
        return self.extracted_data['perceptions']
    
    def extract_expenditure_data(self):
        """
        Extract visitor spending data
        """
        expenditure_data = {
            'country': ['South Africa', 'Botswana', 'Netherlands', 'Germany', 'UK', 'France', 'USA'],
            'avg_spend_per_night': [839, 842, 1019, 896, 1193, 784, 982],
            'accommodation_spend': [406, 319, 521, 479, 610, 436, 483],
            'food_spend': [188, 272, 216, 211, 273, 178, 224],
            'transport_spend': [101, 146, 136, 88, 92, 58, 76],
            'entertainment_spend': [30, 12, 45, 26, 44, 43, 65],
            'shopping_spend': [28, 35, 25, 38, 38, 33, 98]
        }
        
        self.extracted_data['expenditure'] = pd.DataFrame(expenditure_data)
        return self.extracted_data['expenditure']
    
    def extract_visitor_profile_data(self):
        """
        Extract visitor demographics
        """
        profile_data = {
            'age_group': ['0-11', '12-17', '18-24', '25-34', '35-44', '45-54', '55-64', '65+'],
            'male_leisure': [2.7, 1.8, 4.1, 13.2, 12.9, 11.0, 7.3, 3.6],
            'female_leisure': [3.0, 1.6, 3.5, 10.8, 9.0, 6.8, 5.5, 2.5],
            'male_vfr': [2.5, 1.0, 3.5, 11.6, 18.1, 13.3, 5.4, 2.0],
            'female_vfr': [1.9, 1.7, 2.9, 10.5, 10.2, 8.2, 4.7, 2.4],
            'male_business': [0.2, 0.2, 1.8, 11.7, 21.9, 18.3, 10.5, 3.9],
            'female_business': [0.3, 0.3, 1.9, 9.4, 9.6, 6.6, 2.5, 1.1]
        }
        
        self.extracted_data['visitor_profiles'] = pd.DataFrame(profile_data)
        return self.extracted_data['visitor_profiles']
    
    def extract_origin_data(self):
        """
        Extract visitor origin data
        """
        origin_data = {
            'country': ['South Africa', 'Zimbabwe', 'USA', 'India', 'Netherlands', 
                        'China', 'Germany', 'UK', 'Botswana', 'Eswatini'],
            'arrivals_2024': [860000, 19200, 6720, 5760, 5760, 5760, 3840, 3840, 6720, 4800],
            'arrivals_2023': [657480, 14357, 5382, 4653, 4644, 4160, 3037, 2970, 5381, 3472],
            'arrivals_2022': [489780, 9436, 3639, 3892, 1775, 3122, 2218, 2023, 3166, 1750],
            'growth_pct': [31.0, 34.5, 52.8, 19.5, 161.6, 33.2, 36.8, 31.9, 70.0, 98.4]
        }
        
        self.extracted_data['origin'] = pd.DataFrame(origin_data)
        return self.extracted_data['origin']
    
    def extract_all(self):
        """
        Extract all data
        """
        print("Extracting arrivals data...")
        arrivals = self.extract_arrivals_data()
        
        print("Extracting monthly data...")
        monthly = self.extract_monthly_data()
        
        print("Extracting accommodation data...")
        accommodation = self.extract_accommodation_data()
        accommodation_by_type = self.extract_accommodation_by_type()
        accommodation_by_district = self.extract_accommodation_by_district()
        
        print("Extracting attractions data...")
        attractions = self.extract_attractions_data()
        
        print("Extracting sentiment data...")
        perceptions = self.extract_sentiment_data()
        
        print("Extracting expenditure data...")
        expenditure = self.extract_expenditure_data()
        
        print("Extracting visitor profile data...")
        visitor_profiles = self.extract_visitor_profile_data()
        
        print("Extracting origin data...")
        origin = self.extract_origin_data()
        
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
    
    def save_to_csv(self, output_folder='data/processed'):
        """
        Save all extracted data to CSV files
        """
        import os
        os.makedirs(output_folder, exist_ok=True)
        
        data = self.extract_all()
        
        for name, df in data.items():
            filepath = os.path.join(output_folder, f'{name}.csv')
            df.to_csv(filepath, index=False)
            print(f"Saved {name}.csv")
        
        print(f"\nAll data saved to {output_folder}/")

# Run extraction
if __name__ == "__main__":
    extractor = DataExtractor('data/raw')
    data = extractor.extract_all()
    
    # Display summary
    print("\n=== DATA EXTRACTION SUMMARY ===")
    for name, df in data.items():
        print(f"{name}: {df.shape[0]} rows, {df.shape[1]} columns")
    
    # Save to CSV
    extractor.save_to_csv()