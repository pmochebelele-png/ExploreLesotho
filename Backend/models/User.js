// models/User.js
class User {
    constructor(data) {
        this.id = data.user_id || data._id;
        this.email = data.email;
        this.fullName = data.full_name || data.fullName;
        this.role = data.role;
        this.phone = data.phone;
        this.createdAt = data.created_at || data.createdAt;
    }

    // For MongoDB
    toMongoDB() {
        return {
            email: this.email,
            fullName: this.fullName,
            role: this.role,
            phone: this.phone,
            createdAt: new Date(),
            updatedAt: new Date()
        };
    }

    // For MySQL
    toMySQL() {
        return {
            email: this.email,
            full_name: this.fullName,
            role: this.role,
            phone: this.phone,
            password_hash: 'MONGODB_AUTH_ONLY'
        };
    }

    // Static method to create from MySQL row
    static fromMySQL(row) {
        return new User({
            user_id: row.user_id,
            email: row.email,
            full_name: row.full_name,
            role: row.role,
            phone: row.phone,
            created_at: row.created_at
        });
    }

    // Static method to create from MongoDB doc
    static fromMongoDB(doc) {
        return new User({
            _id: doc._id,
            email: doc.email,
            fullName: doc.fullName,
            role: doc.role,
            phone: doc.phone,
            createdAt: doc.createdAt
        });
    }
}

module.exports = User;