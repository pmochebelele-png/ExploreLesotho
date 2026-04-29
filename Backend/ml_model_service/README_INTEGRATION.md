Explore Lesotho ML Service

Run from `Backend/ml_model_service`.

Recommended startup:

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python flask_api.py
```

The Node backend proxies ML requests through:

- `GET /api/ml/dashboard`
- `GET /api/ml/forecast`
- `GET /api/ml/hotspots`
- `GET /api/ml/culture/locations`
- `POST /api/ml/recommend`
- `POST /api/ml/sentiment`
- `POST /api/ml/culture/recommendations`
- `POST /api/ml/check-user`
- `POST /api/ml/register-vendor`
- `GET /api/ml/ltdc/overview`
- `GET /api/ml/ltdc/trends`
- `GET /api/ml/ltdc/insights`
- `POST /api/ml/ltdc/knowledge`
- `POST /api/ml/reviews/analyze`
- `POST /api/ml/analyze-sentiment`
- `POST /api/ml/verify-pdf`

Configuration:

- Optional env var: `ML_SERVICE_URL=http://127.0.0.1:5001/api/ml`

Recommended app startup order:

1. Start the ML service
2. Start the Node backend
3. Start Flutter

From `Backend`, you can use:

```powershell
npm run start:ml
```

From another terminal:

```powershell
npm start
```

Then from `frontend`:

```powershell
flutter run -d chrome
```

Notes:

- `flask_api.py` is the merged finished entrypoint for this package.
- `api_server.py` expects `models/analytics_engine.pkl`, but that file is not present in this package.
- The finished model bundle has been merged into this service, including LTDC knowledge and review sentiment code.
- `models/review_sentiment_model.pkl` is still not present, so sentiment endpoints will only become fully active after training or adding that artifact.
- This package is currently integrated as a backend ML service. The mobile app consumes it through the backend API.
- If you want the model to live fully on-device inside the Android/iPhone app, it would need to be exported to a mobile runtime such as TensorFlow Lite or ONNX Mobile first.
