# Explore Lesotho Release Plan

## Order
1. Rotate secrets
2. Create MongoDB Atlas production database
3. Create Railway MySQL production database
4. Deploy Node backend to Railway
5. Optionally deploy ML service
6. Point Flutter APK to production API
7. Test on Android

## Step 1: Rotate Secrets
- Replace `JWT_SECRET`
- Replace MongoDB database user/password
- Replace MySQL password

## Step 2: MongoDB Atlas
- Create or reuse an Atlas project
- Create a production database user
- Add the Railway outbound IP rule if needed, or temporarily allow wider access during setup
- Copy the connection string
- Set:
  - `MONGODB_URI`
  - `MONGODB_DB_NAME=explore_lesotho`

## Step 3: Railway MySQL
- Create a Railway project
- Add a MySQL database service
- Copy the generated variables:
  - `MYSQLHOST`
  - `MYSQLPORT`
  - `MYSQLUSER`
  - `MYSQLPASSWORD`
  - `MYSQLDATABASE`

## Step 4: Backend on Railway
- Deploy the `Backend` folder as a Node service
- Set variables:
  - `NODE_ENV=production`
  - `PORT=3001`
  - `CLIENT_URL=https://your-web-url`
  - `JWT_SECRET=...`
  - `MONGODB_URI=...`
  - `MONGODB_DB_NAME=explore_lesotho`
- Add either:
  - Railway MySQL generated variables
  - or `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`

## Step 5: ML Service
- Deploy only if live AI dashboards are required now
- Then set:
  - `ML_SERVICE_URL=https://your-ml-service-url/api/ml`

## Step 6: Build APK
```powershell
cd frontend
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-domain/api
```

## Step 7: Final Test
- Login as tourist
- Login as vendor
- Login as admin
- Test messaging
- Test listings/events/culture
- Test booking flow
- Test offline browsing
