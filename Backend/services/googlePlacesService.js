const GOOGLE_PLACES_TEXT_SEARCH_URL =
    'https://places.googleapis.com/v1/places:searchText';

const MASERU_CENTER = { latitude: -29.3151, longitude: 27.4869 };

const fallbackHotels = [
    ['Noble Hearts Bed & Breakfast', 'Maseru West', 4.8, 27, 1320],
    ['Foothills Guesthouse', 'Airport Road, Maseru', 4.3, 197, 747],
    ['Mpilo Boutique Hotel', 'Maseru', 4.3, 197, 1895],
    ['City Stay West', 'Maseru', 4.1, 60, 807],
    ['Denver Echo Executive Guesthouse', 'Maseru', 4.3, 3, 1712],
    ['Seilatsatsi B&B', 'Maseru', 3.4, 21, 1000],
    ['Scenery Guest House Maqalika', 'Maqalika, Maseru', 3.7, 56, 1452],
    ['Lakeside Hotel', 'Maseru', 4.0, 34, 1452],
    ['Mohalalitoe Bed & Breakfast', 'Maseru', 4.2, 19, 807],
    ['My Kasi Home BnB', 'Maseru', 4.2, 16, 799],
    ['TAUNG Guesthouse', 'Upper Thamae, Maseru', 4.1, 22, 881],
    ['City Stay Maseru', 'Maseru', 3.9, 60, 799],
    ['Thabeng Hotel & Restaurant', 'Maseru', 4.1, 80, 1149],
    ['Jate Guest House', 'Maseru', 3.9, 11, 881],
    ['The Anne Guest House', 'Maseru', 4.4, 58, 1402],
    ['Khali Hotel', 'Maseru', 4.0, 45, 1149],
    ['Mohokare Guest House', 'Maseru', 4.0, 30, 1149],
    ['Lancer\'s Inn Hotel Maseru', 'Maseru', 4.1, 325, 2226],
    ['Avani Maseru Hotel', 'Maseru', 4.1, 408, 2229],
    ['Hokahanya Inn & Conference Centre', 'Maseru', 4.4, 110, 1149],
    ['The Mon BnB', 'Maseru', 4.8, 9, 881],
];

function slugify(value) {
    return value
        .toString()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');
}

function mapHotelToListing({
    id,
    title,
    location,
    rating,
    reviewCount,
    price,
    source,
    latitude,
    longitude,
    website,
    phone,
    googleMapsUri,
}) {
    return {
        id,
        title,
        description:
            'Accommodation option discovered from the Maseru hotel map. Confirm availability, price, and policies before booking.',
        category: 'Accommodation',
        price: Number(price || 0),
        priceUnit: '/night',
        location: location || 'Maseru',
        district: 'Maseru',
        rating: rating == null ? null : Number(rating),
        reviewCount: Number(reviewCount || 0),
        imageUrl: 'assets/images/tourism_seed/avani_maseru_1.jpg',
        images: ['assets/images/tourism_seed/avani_maseru_1.jpg'],
        isFeatured: false,
        isAvailable: true,
        vendorId: id,
        vendorName: title,
        vendorPhone: phone || null,
        vendorEmail: null,
        vendorWebsite: website || googleMapsUri || null,
        additionalDetails: {
            source,
            sourceLabel: source === 'google_places' ? 'Google Places' : 'Maseru hotel map',
            latitude,
            longitude,
            googleMapsUri,
        },
    };
}

function fallbackListings() {
    return fallbackHotels.map(([name, location, rating, reviews, price]) =>
        mapHotelToListing({
            id: `map-hotel-${slugify(name)}`,
            title: name,
            location,
            rating,
            reviewCount: reviews,
            price,
            source: 'fallback',
        })
    );
}

function priceFromLevel(priceLevel) {
    const map = {
        PRICE_LEVEL_FREE: 0,
        PRICE_LEVEL_INEXPENSIVE: 650,
        PRICE_LEVEL_MODERATE: 1100,
        PRICE_LEVEL_EXPENSIVE: 1800,
        PRICE_LEVEL_VERY_EXPENSIVE: 2600,
    };
    return map[priceLevel] || 1000;
}

function mapPlace(place) {
    const displayName = place.displayName?.text || place.name || 'Maseru hotel';
    const location = place.formattedAddress || place.shortFormattedAddress || 'Maseru';
    return mapHotelToListing({
        id: `google-${slugify(place.id || displayName)}`,
        title: displayName,
        location,
        rating: place.rating,
        reviewCount: place.userRatingCount,
        price: priceFromLevel(place.priceLevel),
        source: 'google_places',
        latitude: place.location?.latitude,
        longitude: place.location?.longitude,
        website: place.websiteUri,
        phone: place.nationalPhoneNumber || place.internationalPhoneNumber,
        googleMapsUri: place.googleMapsUri,
    });
}

async function fetchMaseruHotels({ query = 'hotels in Maseru Lesotho', limit = 20 } = {}) {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.GOOGLE_PLACES_API_KEY;
    if (!apiKey) {
        return {
            configured: false,
            source: 'fallback',
            listings: fallbackListings(),
        };
    }

    const response = await fetch(GOOGLE_PLACES_TEXT_SEARCH_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': [
                'places.id',
                'places.displayName',
                'places.formattedAddress',
                'places.shortFormattedAddress',
                'places.rating',
                'places.userRatingCount',
                'places.priceLevel',
                'places.location',
                'places.nationalPhoneNumber',
                'places.internationalPhoneNumber',
                'places.websiteUri',
                'places.googleMapsUri',
            ].join(','),
        },
        body: JSON.stringify({
            textQuery: query,
            includedType: 'lodging',
            maxResultCount: Math.min(Math.max(Number(limit) || 20, 1), 20),
            locationBias: {
                circle: {
                    center: MASERU_CENTER,
                    radius: 9000,
                },
            },
        }),
    });

    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(body.error?.message || `Google Places returned ${response.status}`);
    }

    const places = Array.isArray(body.places) ? body.places : [];
    return {
        configured: true,
        source: 'google_places',
        listings: places.map(mapPlace),
    };
}

module.exports = {
    fetchMaseruHotels,
    fallbackListings,
};
