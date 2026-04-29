import pandas as pd
import numpy as np
from datetime import datetime

print("="*70)
print("🤖 CREATING TRAINING DATA FOR SYSTEM AUTO-APPROVAL")
print("="*70)

# ============================================
# APPROVAL RULES (Based on Ministry of Tourism)
# ============================================
print("\n📋 SYSTEM APPROVAL RULES:")
print("-" * 50)
print("A vendor is AUTO-APPROVED if ALL of these are TRUE:")
print("   1. Has valid business license ✓")
print("   2. License is not expired ✓")
print("   3. Has tax clearance certificate ✓")
print("   4. Has 2+ years experience OR rating >= 4.0 ✓")
print("   5. Business type matches approved categories ✓")
print("   6. No negative history in system ✓")
print("\nOtherwise, vendor is AUTO-REJECTED with reason")

# ============================================
# GENERATE TRAINING DATA WITH SYSTEM DECISIONS
# ============================================
print("\n📊 Generating training data with SYSTEM decisions...")

np.random.seed(42)
n_vendors = 2000

vendor_data = {
    'vendor_id': [],
    'business_name': [],
    'business_type': [],
    'district': [],
    'has_license': [],           # 1 = Yes, 0 = No
    'license_valid': [],         # 1 = Valid, 0 = Expired
    'license_expiry_date': [],   # Expiry date
    'tax_clearance': [],         # 1 = Has, 0 = No
    'previous_experience_years': [],
    'rating': [],                # From previous platform (0-5)
    'negative_history': [],      # 1 = Has complaints, 0 = Clean
    'business_category_approved': [], # 1 = Approved category, 0 = Not approved
    'registration_date': [],
    'system_decision': [],       # 1 = Auto-approve, 0 = Auto-reject
    'rejection_reason': []       # Why rejected
}

# Approved business categories (from Ministry of Tourism)
approved_categories = [
    'accommodation', 'tour_operator', 'restaurant', 
    'activity_provider', 'craft_shop', 'transport'
]

business_types = approved_categories + ['unlicensed_taxi', 'street_vendor', 'unregistered']

for i in range(n_vendors):
    vendor_id = f"V{i+1:04d}"
    business_name = f"Business_{vendor_id}"
    
    # Generate random values
    business_type = np.random.choice(business_types)
    business_category_approved = 1 if business_type in approved_categories else 0
    
    has_license = np.random.choice([1, 0], p=[0.75, 0.25])
    
    # License validity (if has license)
    if has_license == 1:
        # 90% valid, 10% expired
        license_valid = np.random.choice([1, 0], p=[0.90, 0.10])
        if license_valid == 1:
            # Valid license: expiry in future
            expiry_date = datetime.now() + pd.Timedelta(days=np.random.randint(30, 365))
        else:
            # Expired license: expiry in past
            expiry_date = datetime.now() - pd.Timedelta(days=np.random.randint(1, 365))
    else:
        license_valid = 0
        expiry_date = None
    
    tax_clearance = np.random.choice([1, 0], p=[0.80, 0.20])
    previous_experience = np.random.randint(0, 20)
    rating = np.random.uniform(0, 5)
    negative_history = np.random.choice([1, 0], p=[0.15, 0.85])
    
    # SYSTEM DECISION LOGIC (Auto-approve or Auto-reject)
    reject_reasons = []
    
    # Rule 1: Must have license
    if has_license != 1:
        reject_reasons.append("Missing business license")
    
    # Rule 2: License must be valid
    if has_license == 1 and license_valid != 1:
        reject_reasons.append("License is expired")
    
    # Rule 3: Must have tax clearance
    if tax_clearance != 1:
        reject_reasons.append("Missing tax clearance certificate")
    
    # Rule 4: Experience or rating requirement
    if previous_experience < 2 and rating < 4.0:
        reject_reasons.append(f"Insufficient experience ({previous_experience} years) and low rating ({rating:.1f})")
    
    # Rule 5: Business type must be approved
    if business_category_approved != 1:
        reject_reasons.append(f"Business type '{business_type}' not approved by Ministry of Tourism")
    
    # Rule 6: No negative history
    if negative_history == 1:
        reject_reasons.append("Has negative history/complaints in system")
    
    # Final decision
    if len(reject_reasons) == 0:
        system_decision = 1  # AUTO-APPROVE
        rejection_reason = ""
    else:
        system_decision = 0  # AUTO-REJECT
        rejection_reason = "; ".join(reject_reasons)
    
    # Add to dataset
    vendor_data['vendor_id'].append(vendor_id)
    vendor_data['business_name'].append(business_name)
    vendor_data['business_type'].append(business_type)
    vendor_data['district'].append(np.random.choice(['Maseru', 'Leribe', 'Berea', 'Mafeteng', "Mohale's Hoek", 'Quthing', 'Qacha\'s Nek', 'Mokhotlong', 'Butha-Buthe', 'Thaba-Tseka']))
    vendor_data['has_license'].append(has_license)
    vendor_data['license_valid'].append(license_valid)
    vendor_data['license_expiry_date'].append(expiry_date)
    vendor_data['tax_clearance'].append(tax_clearance)
    vendor_data['previous_experience_years'].append(previous_experience)
    vendor_data['rating'].append(round(rating, 1))
    vendor_data['negative_history'].append(negative_history)
    vendor_data['business_category_approved'].append(business_category_approved)
    vendor_data['registration_date'].append(datetime.now() - pd.Timedelta(days=np.random.randint(0, 365)))
    vendor_data['system_decision'].append(system_decision)
    vendor_data['rejection_reason'].append(rejection_reason)

# Create DataFrame
df = pd.DataFrame(vendor_data)

# Save to CSV
df.to_csv('vendor_system_approval_data.csv', index=False)

print(f"\n✅ Created training dataset with {len(df)} vendors")
print(f"\n📊 Dataset Statistics:")
print(f"   Auto-Approved: {df['system_decision'].sum()} ({df['system_decision'].mean()*100:.1f}%)")
print(f"   Auto-Rejected: {len(df) - df['system_decision'].sum()} ({(1-df['system_decision'].mean())*100:.1f}%)")

print(f"\n📋 Columns in training data:")
for col in df.columns:
    print(f"   - {col}")

print(f"\n🔍 Sample of AUTO-APPROVED vendor:")
approved_sample = df[df['system_decision'] == 1].head(1)
print(approved_sample[['vendor_id', 'business_type', 'has_license', 'license_valid', 'tax_clearance', 'previous_experience_years', 'rating', 'system_decision']].to_string(index=False))

print(f"\n🔍 Sample of AUTO-REJECTED vendor:")
rejected_sample = df[df['system_decision'] == 0].head(1)
print(rejected_sample[['vendor_id', 'business_type', 'has_license', 'license_valid', 'tax_clearance', 'previous_experience_years', 'rating', 'system_decision', 'rejection_reason']].to_string(index=False))

print("\n" + "="*70)
print("✅ SYSTEM APPROVAL TRAINING DATA CREATED!")
print("="*70)
print("\n📁 File saved: vendor_system_approval_data.csv")
print("\n🤖 Now training the ML model to learn these rules...")