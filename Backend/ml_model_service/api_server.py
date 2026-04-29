# ml_model/api_server.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from vendor_verifier import VendorVerifier
from analytics_engine import AnalyticsEngine
import joblib
import json

app = Flask(__name__)
CORS(app)

# Load trained models
vendor_verifier = VendorVerifier()
vendor_verifier.load_model('models/vendor_classifier.pkl')

analytics_engine = joblib.load('models/analytics_engine.pkl')

@app.route('/api/ml/verify-vendor', methods=['POST'])
def verify_vendor():
    """Verify vendor registration using ML model"""
    try:
        vendor_data = request.json
        result = vendor_verifier.predict(vendor_data)
        return jsonify({
            'success': True,
            'result': result
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ml/demand-forecast', methods=['GET'])
def demand_forecast():
    """Get demand forecast"""
    try:
        days = request.args.get('days', 30, type=int)
        forecast = analytics_engine.predict_demand(days)
        return jsonify({
            'success': True,
            'forecast': forecast,
            'total_forecast': sum(forecast)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ml/analyze-sentiment', methods=['POST'])
def analyze_sentiment():
    """Analyze review sentiment"""
    try:
        reviews = request.json.get('reviews', [])
        result = analytics_engine.analyze_sentiment(reviews)
        return jsonify({
            'success': True,
            'analysis': result
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ml/generate-insights', methods=['POST'])
def generate_insights():
    """Generate actionable insights"""
    try:
        data = request.json
        insights = analytics_engine.generate_insights(data)
        return jsonify({
            'success': True,
            'insights': insights
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ml/customer-segments', methods=['POST'])
def customer_segments():
    """Segment customers"""
    try:
        user_data = request.json.get('users', [])
        segments = analytics_engine.segment_customers(user_data)
        return jsonify({
            'success': True,
            'segments': segments
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(port=5001, debug=True)