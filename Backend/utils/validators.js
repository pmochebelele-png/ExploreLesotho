// utils/validators.js

// Validate email format
const validateEmail = (email) => {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
};

// Validate Lesotho phone number
const validatePhone = (phone) => {
    const re = /^\+266\d{8}$/;
    return re.test(phone);
};

// Validate date range
const validateDates = (checkIn, checkOut) => {
    const start = new Date(checkIn);
    const end = new Date(checkOut);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    return start < end && start >= today;
};

// Validate booking data
const validateBooking = (data) => {
    const errors = [];
    
    if (!data.listing_id) errors.push('Listing ID is required');
    if (!data.check_in) errors.push('Check-in date is required');
    if (!data.check_out) errors.push('Check-out date is required');
    if (!data.guests) errors.push('Number of guests is required');
    if (!data.total_price) errors.push('Total price is required');
    
    if (data.guests && data.guests < 1) {
        errors.push('At least 1 guest required');
    }
    
    if (data.guests && data.guests > 20) {
        errors.push('Maximum 20 guests allowed');
    }
    
    if (data.total_price && data.total_price <= 0) {
        errors.push('Total price must be greater than 0');
    }
    
    return errors;
};

// Validate registration data
const validateRegistration = (data) => {
    const errors = [];
    
    if (!data.email) errors.push('Email is required');
    else if (!validateEmail(data.email)) errors.push('Invalid email format');
    
    if (!data.password) errors.push('Password is required');
    else if (data.password.length < 8) errors.push('Password must be at least 8 characters');
    
    if (!data.fullName) errors.push('Full name is required');
    
    if (data.phone && !validatePhone(data.phone)) {
        errors.push('Phone must be in format: +266XXXXXXXX');
    }
    
    return errors;
};

// Sanitize input
const sanitizeString = (str) => {
    if (!str) return '';
    return str.replace(/[<>]/g, '').trim();
};

module.exports = {
    validateEmail,
    validatePhone,
    validateDates,
    validateBooking,
    validateRegistration,
    sanitizeString
};