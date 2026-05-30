const express = require('express');

const router = express.Router();

const DEFAULT_DAILY_COSTS = {
    budget: {
        accommodation: 450,
        breakfast: 80,
        lunch: 120,
        dinner: 160,
        localTransport: 180,
        activities: 250,
        guide: 120,
    },
    standard: {
        accommodation: 850,
        breakfast: 120,
        lunch: 180,
        dinner: 260,
        localTransport: 350,
        activities: 450,
        guide: 250,
    },
    premium: {
        accommodation: 1600,
        breakfast: 180,
        lunch: 300,
        dinner: 480,
        localTransport: 750,
        activities: 900,
        guide: 550,
    },
};

const ORIGIN_MULTIPLIERS = {
    lesotho: 0.85,
    'south africa': 1,
    egypt: 1.12,
    germany: 1.25,
    usa: 1.3,
    uk: 1.25,
};

const FACILITY_HIERARCHY = {
    accommodation: ['guest_house', 'hotel', 'lodge', 'bed_and_breakfast', 'camping'],
    tour: ['heritage_tour', 'city_tour', 'thaba_bosiu', 'museum', 'cultural_route'],
    adventure: ['hiking', 'skiing', 'pony_trekking', 'abseiling', '4x4'],
    experience: ['culture', 'crafts', 'food', 'festival', 'village_visit'],
    transport: ['airport_transfer', 'local_taxi', 'car_hire', 'tour_shuttle'],
    food: ['breakfast', 'lunch', 'dinner', 'restaurant'],
    sport: ['skiing', 'running', 'cycling', 'water_sport'],
};

router.post('/plan', (req, res) => {
    const days = Math.max(1, Number.parseInt(req.body.days, 10) || 3);
    const travelers = Math.max(1, Number.parseInt(req.body.travelers, 10) || 1);
    const style = DEFAULT_DAILY_COSTS[req.body.style] ? req.body.style : 'standard';
    const origin = String(req.body.originCountry || '').trim().toLowerCase();
    const multiplier = ORIGIN_MULTIPLIERS[origin] || 1.15;
    const costs = DEFAULT_DAILY_COSTS[style];

    const dailyPerPerson = Object.values(costs).reduce((sum, value) => sum + value, 0);
    const subtotal = dailyPerPerson * days * travelers;
    const contingency = subtotal * 0.1;
    const serviceFee = subtotal * 0.05;
    const total = subtotal + contingency + serviceFee;

    res.json({
        success: true,
        currency: 'LSL',
        originCountry: req.body.originCountry || 'International',
        style,
        days,
        travelers,
        dailyPerPerson,
        costBreakdown: Object.entries(costs).map(([key, value]) => ({
            item: key,
            dailyPerPerson: value,
            total: Number((value * days * travelers * multiplier).toFixed(2)),
        })),
        totals: {
            subtotal: Number((subtotal * multiplier).toFixed(2)),
            contingency: Number((contingency * multiplier).toFixed(2)),
            platformPlanningFee: Number((serviceFee * multiplier).toFixed(2)),
            estimatedTotal: Number((total * multiplier).toFixed(2)),
        },
        recommendations: [
            'Book accommodation before arrival during peak December demand.',
            'Separate accommodation, tours, adventure, food, and transport in the itinerary.',
            'Keep at least 10% contingency for route changes, weather, and extra activities.',
        ],
    });
});

router.get('/facility-hierarchy', (_req, res) => {
    res.json({
        success: true,
        hierarchy: FACILITY_HIERARCHY,
    });
});

module.exports = router;
