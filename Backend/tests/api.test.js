// tests/api.test.js
const request = require('supertest');
const { expect } = require('chai');

// Note: You'll need to export your app from server.js
// Add this at the bottom of server.js: module.exports = app;
const app = require('../server');

describe('Explore Lesotho API Tests', () => {
    let authToken;
    let bookingId;

    // Test user data
    const testUser = {
        email: `test${Date.now()}@example.com`,
        password: 'Test123!',
        fullName: 'Test User',
        role: 'tourist',
        phone: '+26612345678'
    };

    describe('Authentication', () => {
        it('should register a new user', async () => {
            const res = await request(app)
                .post('/api/auth/register')
                .send(testUser);
            
            expect(res.status).to.equal(201);
            expect(res.body).to.have.property('token');
            expect(res.body.user.email).to.equal(testUser.email);
        });

        it('should login existing user', async () => {
            const res = await request(app)
                .post('/api/auth/login')
                .send({
                    email: testUser.email,
                    password: testUser.password
                });
            
            expect(res.status).to.equal(200);
            expect(res.body).to.have.property('token');
            authToken = res.body.token;
        });
    });

    describe('Listings', () => {
        it('should get listing details', async () => {
            const res = await request(app)
                .get('/api/listings/1/complete');
            
            expect(res.status).to.equal(200);
            expect(res.body).to.have.property('listing');
            expect(res.body.listing.listing_id).to.equal(1);
        });

        it('should return 404 for non-existent listing', async () => {
            const res = await request(app)
                .get('/api/listings/999/complete');
            
            expect(res.status).to.equal(404);
        });
    });

    describe('Bookings', () => {
        it('should create a booking with auth token', async () => {
            const res = await request(app)
                .post('/api/bookings')
                .set('Authorization', `Bearer ${authToken}`)
                .send({
                    listing_id: 8,
                    check_in: '2026-05-15',
                    check_out: '2026-05-17',
                    guests: 2,
                    total_price: 900.00,
                    special_requests: 'Test booking'
                });
            
            expect(res.status).to.equal(201);
            expect(res.body).to.have.property('booking');
            expect(res.body.booking.status).to.equal('confirmed');
            bookingId = res.body.booking.id;
        });

        it('should get user bookings', async () => {
            // First get user_id from MySQL
            const mysql = require('mysql2/promise');
            const conn = await mysql.createConnection({
                host: process.env.DB_HOST || 'localhost',
                user: process.env.DB_USER || 'root',
                password: process.env.DB_PASSWORD || '12345',
                database: 'explore_lesotho'
            });

            const [users] = await conn.execute(
                'SELECT user_id FROM users WHERE email = ?',
                [testUser.email]
            );

            await conn.end();

            const userId = users[0]?.user_id;

            const res = await request(app)
                .get(`/api/bookings/user/${userId}`)
                .set('Authorization', `Bearer ${authToken}`);
            
            expect(res.status).to.equal(200);
            expect(res.body).to.have.property('bookings');
            expect(res.body.bookings.length).to.be.at.least(1);
        });

        it('should cancel booking', async () => {
            const res = await request(app)
                .put(`/api/bookings/${bookingId}/cancel`)
                .set('Authorization', `Bearer ${authToken}`)
                .send({ reason: 'Test cancellation' });
            
            expect(res.status).to.equal(200);
            expect(res.body.status).to.equal('cancelled');
        });
    });

    describe('Health Check', () => {
        it('should return API health status', async () => {
            const res = await request(app)
                .get('/api/health');
            
            expect(res.status).to.equal(200);
            expect(res.body).to.have.property('status', 'OK');
            expect(res.body).to.have.property('mongodb', 'connected');
            expect(res.body).to.have.property('mysql', 'connected');
        });
    });
});