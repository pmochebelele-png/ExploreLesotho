import pandas as pd
import numpy as np
from datetime import datetime, timedelta

print("="*70)
print("📝 CREATING TRAINING DATA TEMPLATE")
print("="*70)

# ============================================
# 1. VENDOR REGISTRATION DATA TEMPLATE
# ============================================
print("\n📊 1. VENDOR REGISTRATION DATA")
print("-" * 50)

# Create sample vendor data
vendor_data = {
    'vendor_id': [],
    'business_name': [],
    'business_type': [],
    'district': [],
    'has_license': [],
    'license_valid': [],
    'tax_clearance': [],
    'previous_experience_years': [],
    'rating': [],
    'approved_by_admin': [],  # This is your target variable (what you want to predict)
    'registration_date': []
}

# Add some sample data (replace with your real data)
sample_vendors = [
    ['V001', 'Maliba Lodge', 'accommodation', 'Butha-Buthe', 1, 1, 1, 5, 4.8, 1, '2024-01-15'],
    ['V002', 'Pony Trekking', 'tour_operator', 'Mafeteng', 1, 1, 1, 3, 4.5, 1, '2024-02-20'],
    ['V003', 'Mountain Tours', 'tour_operator', 'Maseru', 1, 0, 1, 2, 3.2, 0, '2024-03-10'],
    ['V004', 'Sani Pass Tours', 'tour_operator', 'Qacha\'s Nek', 1, 1, 1, 7, 4.9, 1, '2024-01-05'],
    ['V005', 'Craft Market', 'craft_shop', 'Maseru', 0, 0, 0, 1, 0, 0, '2024-04-01'],
]

for v in sample_vendors:
    vendor_data['vendor_id'].append(v[0])
    vendor_data['business_name'].append(v[1])
    vendor_data['business_type'].append(v[2])
    vendor_data['district'].append(v[3])
    vendor_data['has_license'].append(v[4])
    vendor_data['license_valid'].append(v[5])
    vendor_data['tax_clearance'].append(v[6])
    vendor_data['previous_experience_years'].append(v[7])
    vendor_data['rating'].append(v[8])
    vendor_data['approved_by_admin'].append(v[9])
    vendor_data['registration_date'].append(v[10])

vendor_df = pd.DataFrame(vendor_data)
vendor_df.to_csv('vendor_training_data.csv', index=False)
print(f"✅ Created vendor_training_data.csv with {len(vendor_df)} records")
print("\n📋 Columns:")
for col in vendor_df.columns:
    print(f"   - {col}")

# ============================================
# 2. BOOKING DATA TEMPLATE
# ============================================
print("\n📊 2. BOOKING DATA")
print("-" * 50)

# Create sample booking data
booking_data = {
    'booking_id': [],
    'listing_id': [],
    'vendor_id': [],
    'check_in_date': [],
    'check_out_date': [],
    'guests': [],
    'total_price': [],
    'status': [],
    'created_date': []
}

sample_bookings = [
    ['B001', 'L001', 'V001', '2024-06-01', '2024-06-03', 2, 3700, 'completed', '2024-05-15'],
    ['B002', 'L002', 'V002', '2024-06-05', '2024-06-06', 1, 650, 'completed', '2024-05-20'],
    ['B003', 'L001', 'V001', '2024-06-10', '2024-06-12', 3, 5550, 'confirmed', '2024-05-25'],
    ['B004', 'L003', 'V003', '2024-06-15', '2024-06-16', 2, 1200, 'pending', '2024-06-01'],
    ['B005', 'L001', 'V001', '2024-06-20', '2024-06-22', 2, 3700, 'completed', '2024-06-05'],
]

for b in sample_bookings:
    booking_data['booking_id'].append(b[0])
    booking_data['listing_id'].append(b[1])
    booking_data['vendor_id'].append(b[2])
    booking_data['check_in_date'].append(b[3])
    booking_data['check_out_date'].append(b[4])
    booking_data['guests'].append(b[5])
    booking_data['total_price'].append(b[6])
    booking_data['status'].append(b[7])
    booking_data['created_date'].append(b[8])

booking_df = pd.DataFrame(booking_data)
booking_df.to_csv('booking_training_data.csv', index=False)
print(f"✅ Created booking_training_data.csv with {len(booking_df)} records")

# ============================================
# 3. REVIEW DATA TEMPLATE
# ============================================
print("\n📊 3. REVIEW DATA")
print("-" * 50)

review_data = {
    'review_id': [],
    'listing_id': [],
    'user_name': [],
    'rating': [],
    'comment': [],
    'created_date': []
}

sample_reviews = [
    ['R001', 'L001', 'John D.', 5, 'Amazing place, beautiful views!', '2024-06-04'],
    ['R002', 'L002', 'Mary S.', 4, 'Great adventure, ponies well trained', '2024-06-07'],
    ['R003', 'L001', 'Peter K.', 5, 'Excellent service, will come back', '2024-06-13'],
    ['R004', 'L003', 'Sarah M.', 3, 'Good but expensive', '2024-06-17'],
]

for r in sample_reviews:
    review_data['review_id'].append(r[0])
    review_data['listing_id'].append(r[1])
    review_data['user_name'].append(r[2])
    review_data['rating'].append(r[3])
    review_data['comment'].append(r[4])
    review_data['created_date'].append(r[5])

review_df = pd.DataFrame(review_data)
review_df.to_csv('review_training_data.csv', index=False)
print(f"✅ Created review_training_data.csv with {len(review_df)} records")

print("\n" + "="*70)
print("✅ TEMPLATE FILES CREATED!")
print("="*70)
print("\n📁 Files created:")
print("   1. vendor_training_data.csv - Add your vendor registration data")
print("   2. booking_training_data.csv - Add your booking data")
print("   3. review_training_data.csv - Add your review data")
print("\n📝 Next steps:")
print("   1. Open these CSV files in Excel")
print("   2. Replace sample data with YOUR real business data")
print("   3. Save the files")
print("   4. Run the training script again")