// models/Booking.js
class Booking {
    constructor(data) {
        this.id = data.booking_id;
        this.reference = data.booking_reference;
        this.touristId = data.tourist_id;
        this.listingId = data.listing_id;
        this.checkIn = data.check_in;
        this.checkOut = data.check_out;
        this.guests = data.guests;
        this.totalPrice = data.total_price;
        this.status = data.status;
        this.specialRequests = data.special_requests;
        this.createdAt = data.created_at;
    }

    // Format for API response
    toJSON() {
        return {
            id: this.id,
            reference: this.reference,
            tourist_id: this.touristId,
            listing_id: this.listingId,
            check_in: this.checkIn,
            check_out: this.checkOut,
            guests: this.guests,
            total_price: this.totalPrice,
            status: this.status,
            special_requests: this.specialRequests,
            created_at: this.createdAt
        };
    }

    // Check if booking is upcoming
    isUpcoming() {
        return new Date(this.checkIn) > new Date() && this.status === 'confirmed';
    }

    // Check if booking is active
    isActive() {
        const now = new Date();
        const checkIn = new Date(this.checkIn);
        const checkOut = new Date(this.checkOut);
        return now >= checkIn && now <= checkOut && this.status === 'confirmed';
    }

    // Calculate nights
    getNights() {
        const start = new Date(this.checkIn);
        const end = new Date(this.checkOut);
        const diffTime = Math.abs(end - start);
        return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    }
}

module.exports = Booking;