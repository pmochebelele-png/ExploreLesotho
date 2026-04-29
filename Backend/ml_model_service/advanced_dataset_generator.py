import pandas as pd
import numpy as np
import os

print("🚀 Generating datasets...")

os.makedirs("data", exist_ok=True)

# ============================================
# 👤 USER BEHAVIOR DATASET (FRAUD)
# ============================================
data = []

np.random.seed(42)

for i in range(1000):
    bookings = np.random.randint(0, 20)
    payments = np.random.randint(0, bookings + 1)
    cancellations = np.random.randint(0, bookings + 1)
    failed_payments = np.random.randint(0, 6)
    login_frequency = np.random.randint(1, 100)

    # Fraud logic (same as your model rules)
    fraud = 0
    if bookings > 5 and payments == 0:
        fraud = 1
    elif failed_payments > 3:
        fraud = 1
    elif cancellations > bookings * 0.6:
        fraud = 1
    elif login_frequency > 50:
        fraud = 1

    data.append({
        "bookings_made": bookings,
        "payments_completed": payments,
        "cancellations": cancellations,
        "failed_payments": failed_payments,
        "login_frequency": login_frequency,
        "fraud": fraud
    })

df = pd.DataFrame(data)

df.to_csv("data/user_behavior_dataset.csv", index=False)

print("✅ user_behavior_dataset.csv created")
print(df.head())