# export_to_excel.py - Export AI model results to Excel
import pandas as pd
import numpy as np

print("=" * 60)
print("Exporting AI Model Results to Excel")
print("=" * 60)

# Load all data
data_path = 'Dataset/'
monthly = pd.read_csv(data_path + 'monthly_cleaned.csv')
accommodation = pd.read_csv(data_path + 'accommodation_cleaned.csv')
attractions = pd.read_csv(data_path + 'attractions_cleaned.csv')
perceptions = pd.read_csv(data_path + 'perceptions_cleaned.csv')
origin = pd.read_csv(data_path + 'origin_cleaned.csv')

print("✓ Loaded data")

# Create Excel writer
output_file = 'Dataset/Explore_Lesotho_AI_Insights.xlsx'
with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
    
    # Sheet 1: Seasonal Trends
    seasonal = monthly[['month_name', 'arrivals', 'season', 'quarter', 'is_peak']].copy()
    seasonal.to_excel(writer, sheet_name='Seasonal Trends', index=False)
    print("  ✓ Sheet 1: Seasonal Trends")
    
    # Sheet 2: Attractions Data
    attractions.to_excel(writer, sheet_name='Attractions', index=False)
    print("  ✓ Sheet 2: Attractions")
    
    # Sheet 3: Visitor Sentiment
    perceptions.to_excel(writer, sheet_name='Visitor Sentiment', index=False)
    print("  ✓ Sheet 3: Visitor Sentiment")
    
    # Sheet 4: Origin Markets
    origin.to_excel(writer, sheet_name='Origin Markets', index=False)
    print("  ✓ Sheet 4: Origin Markets")
    
    # Sheet 5: Price Predictions
    price_predictions = []
    for month in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
        month_name = monthly[monthly['month'] == month]['month_name'].values[0]
        arrivals = monthly[monthly['month'] == month]['arrivals'].values[0]
        base_price = 1850
        demand_mult = arrivals / monthly['arrivals'].mean()
        predicted_price = base_price * demand_mult
        price_predictions.append({
            'Month': month_name,
            'Expected Visitors': arrivals,
            'Base Price (M)': base_price,
            'Demand Multiplier': round(demand_mult, 2),
            'Predicted Price (M)': round(predicted_price, 0)
        })
    
    price_df = pd.DataFrame(price_predictions)
    price_df.to_excel(writer, sheet_name='Dynamic Pricing', index=False)
    print("  ✓ Sheet 5: Dynamic Pricing")
    
    # Sheet 6: AI Recommendations
    recommendations = [
        {'Category': 'Peak Season', 'Recommendation': 'Increase prices by 60% in December', 'Impact': 'High'},
        {'Category': 'Marketing', 'Recommendation': 'Target Netherlands and USA markets (high growth)', 'Impact': 'High'},
        {'Category': 'Infrastructure', 'Recommendation': 'Improve road signage based on visitor feedback', 'Impact': 'Medium'},
        {'Category': 'Attractions', 'Recommendation': 'Promote Thaba Bosiu as cultural heritage site', 'Impact': 'High'},
        {'Category': 'Packages', 'Recommendation': 'Create Thaba Bosiu + Morija Museum combo packages', 'Impact': 'Medium'},
        {'Category': 'Adventure', 'Recommendation': 'Develop Maletsunyane Falls adventure packages', 'Impact': 'High'},
        {'Category': 'Accommodation', 'Recommendation': 'Offer winter discounts (June-August) to boost occupancy', 'Impact': 'Medium'},
        {'Category': 'Digital', 'Recommendation': 'Implement dynamic pricing API in Flutter app', 'Impact': 'High'},
    ]
    
    rec_df = pd.DataFrame(recommendations)
    rec_df.to_excel(writer, sheet_name='AI Recommendations', index=False)
    print("  ✓ Sheet 6: AI Recommendations")
    
    # Sheet 7: Key Insights Summary
    insights = [
        {'Insight': 'Peak Tourism Month', 'Value': 'December', 'Data': '99,553 visitors'},
        {'Insight': 'Most Popular Attraction', 'Value': 'Thaba Bosiu', 'Data': '32,097 visitors'},
        {'Insight': 'Top Source Market', 'Value': 'South Africa', 'Data': '94.4% market share'},
        {'Insight': 'Fastest Growing Market', 'Value': 'Netherlands', 'Data': '161.6% growth'},
        {'Insight': 'Visitor Satisfaction', 'Value': '92.4% Positive', 'Data': 'Good Service (37.1%)'},
        {'Insight': 'Main Improvement Area', 'Value': 'Poor Signage', 'Data': '0.4% feedback'},
        {'Insight': 'Average Occupancy Rate', 'Value': '23.6%', 'Data': 'Up from 19.9% in 2023'},
        {'Insight': 'Total Revenue 2024', 'Value': 'M542 Million', 'Data': '20.2% growth'},
        {'Insight': 'Total Employees', 'Value': '2,226', 'Data': 'Skilled workforce: 78.8%'},
        {'Insight': 'International Visitors', 'Value': '960,361', 'Data': '84% of pre-pandemic levels'},
    ]
    
    insights_df = pd.DataFrame(insights)
    insights_df.to_excel(writer, sheet_name='Key Insights', index=False)
    print("  ✓ Sheet 7: Key Insights")

print(f"\n✅ Excel file created: {output_file}")
print(f"\n📂 Location: C:\\Users\\SUBLIME TECHNOLOGIES\\Downloads\\scikit\\Dataset\\Explore_Lesotho_AI_Insights.xlsx")
print("\n💡 You can now open this file in Excel for your presentation!")