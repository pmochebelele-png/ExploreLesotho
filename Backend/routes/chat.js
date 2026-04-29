const express = require('express');
const { ObjectId } = require('mongodb');
const { randomUUID } = require('crypto');
const { mysqlPool, getMongoDb } = require('../config/databases');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken);

let mysqlChatTablesReadyPromise = null;

function isMongoReady() {
    return Boolean(getMongoDb());
}

function getCollections() {
    const db = getMongoDb();
    if (!db) {
        throw new Error('MongoDB is not initialized');
    }

    return {
        conversations: db.collection('chat_conversations'),
        messages: db.collection('chat_messages'),
    };
}

function toObjectId(id) {
    try {
        return new ObjectId(id);
    } catch (_) {
        return null;
    }
}

async function ensureMySqlChatTables() {
    if (!mysqlChatTablesReadyPromise) {
        mysqlChatTablesReadyPromise = (async () => {
            await mysqlPool.execute(`
                CREATE TABLE IF NOT EXISTS chat_conversations (
                    conversation_id VARCHAR(64) PRIMARY KEY,
                    listing_id VARCHAR(64) NULL,
                    listing_title VARCHAR(255) NULL,
                    booking_id VARCHAR(64) NULL,
                    is_active TINYINT(1) NOT NULL DEFAULT 1,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL
                )
            `);

            await mysqlPool.execute(`
                CREATE TABLE IF NOT EXISTS chat_conversation_participants (
                    participant_row_id INT AUTO_INCREMENT PRIMARY KEY,
                    conversation_id VARCHAR(64) NOT NULL,
                    user_id VARCHAR(64) NOT NULL,
                    role VARCHAR(32) NOT NULL,
                    joined_at DATETIME NOT NULL,
                    last_read DATETIME NOT NULL,
                    UNIQUE KEY uniq_conversation_user (conversation_id, user_id),
                    KEY idx_participant_user (user_id),
                    CONSTRAINT fk_chat_participant_conversation
                        FOREIGN KEY (conversation_id) REFERENCES chat_conversations(conversation_id)
                        ON DELETE CASCADE
                )
            `);

            await mysqlPool.execute(`
                CREATE TABLE IF NOT EXISTS chat_messages (
                    message_id VARCHAR(64) PRIMARY KEY,
                    conversation_id VARCHAR(64) NOT NULL,
                    sender_id VARCHAR(64) NOT NULL,
                    sender_name VARCHAR(255) NOT NULL,
                    sender_role VARCHAR(32) NOT NULL,
                    content TEXT NOT NULL,
                    content_type VARCHAR(32) NOT NULL DEFAULT 'text',
                    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    KEY idx_chat_messages_conversation (conversation_id, created_at),
                    CONSTRAINT fk_chat_message_conversation
                        FOREIGN KEY (conversation_id) REFERENCES chat_conversations(conversation_id)
                        ON DELETE CASCADE
                )
            `);
        })().catch((error) => {
            mysqlChatTablesReadyPromise = null;
            throw error;
        });
    }

    return mysqlChatTablesReadyPromise;
}

async function getListingTitle(listingId) {
    if (!listingId) {
        return null;
    }

    try {
        const [rows] = await mysqlPool.execute(
            'SELECT title FROM listings WHERE listing_id = ? LIMIT 1',
            [listingId]
        );
        return rows[0]?.title ?? null;
    } catch (_) {
        return null;
    }
}

async function getParticipantsMeta(userIds) {
    if (!userIds.length) {
        return new Map();
    }

    const placeholders = userIds.map(() => '?').join(', ');
    const [rows] = await mysqlPool.execute(
        `SELECT 
            u.user_id,
            u.full_name,
            u.role,
            u.email,
            v.business_name,
            COALESCE(v.verified, 1) AS verified
         FROM users u
         LEFT JOIN vendors v ON u.user_id = v.user_id
         WHERE u.user_id IN (${placeholders})`,
        userIds
    );

    return new Map(
        rows.map((row) => [
            String(row.user_id),
            {
                userId: String(row.user_id),
                fullName: row.role === 'vendor' && row.business_name
                    ? row.business_name
                    : row.full_name,
                email: row.email,
                role: row.role,
                verified: row.verified === 1 || row.verified === true,
            },
        ])
    );
}

async function getUserDisplayName(userId) {
    const meta = await getParticipantsMeta([String(userId)]);
    return meta.get(String(userId))?.fullName ?? 'User';
}

async function serializeConversation(conversation, currentUserId) {
    const { messages } = getCollections();
    const participantIds = (conversation.participantIds ?? []).map(String);
    const participantMeta = await getParticipantsMeta(participantIds);

    const lastMessage = await messages.find(
        { conversationId: String(conversation._id) },
        { sort: { createdAt: -1 }, limit: 1 }
    ).toArray();

    const unreadCount = await messages.countDocuments({
        conversationId: String(conversation._id),
        senderId: { $ne: currentUserId },
        readBy: { $ne: currentUserId },
        isDeleted: { $ne: true },
    });

    const participants = (conversation.participants ?? []).map((participant) => {
        const meta = participantMeta.get(String(participant.userId));
        return {
            userId: String(participant.userId),
            fullName: meta?.fullName ?? 'Unknown User',
            role: meta?.role ?? participant.role ?? 'tourist',
            joinedAt: participant.joinedAt ?? conversation.createdAt ?? new Date(),
            lastRead: participant.lastRead ?? conversation.createdAt ?? new Date(),
        };
    });

    return {
        _id: String(conversation._id),
        participants,
        participantIds,
        listingId: conversation.listingId ?? null,
        listingTitle: conversation.listingTitle ?? null,
        bookingId: conversation.bookingId ?? null,
        unreadCount,
        isActive: conversation.isActive !== false,
        createdAt: conversation.createdAt ?? new Date(),
        updatedAt: conversation.updatedAt ?? conversation.createdAt ?? new Date(),
        lastMessage: lastMessage[0]
            ? {
                content: lastMessage[0].content,
                senderId: String(lastMessage[0].senderId),
                sentAt: lastMessage[0].createdAt,
            }
            : null,
    };
}

async function serializeSqlConversation(conversationId, currentUserId) {
    await ensureMySqlChatTables();

    const [[conversation]] = await mysqlPool.execute(
        `SELECT conversation_id, listing_id, listing_title, booking_id, is_active, created_at, updated_at
         FROM chat_conversations
         WHERE conversation_id = ? LIMIT 1`,
        [conversationId]
    );

    if (!conversation) {
        return null;
    }

    const [participantRows] = await mysqlPool.execute(
        `SELECT user_id, role, joined_at, last_read
         FROM chat_conversation_participants
         WHERE conversation_id = ?
         ORDER BY joined_at ASC`,
        [conversationId]
    );
    const participantIds = participantRows.map((row) => String(row.user_id));
    const participantMeta = await getParticipantsMeta(participantIds);

    const participants = participantRows.map((participant) => {
        const meta = participantMeta.get(String(participant.user_id));
        return {
            userId: String(participant.user_id),
            fullName: meta?.fullName ?? 'Unknown User',
            role: meta?.role ?? participant.role ?? 'tourist',
            joinedAt: participant.joined_at,
            lastRead: participant.last_read,
        };
    });

    const [[lastMessageRow]] = await mysqlPool.execute(
        `SELECT content, sender_id, created_at
         FROM chat_messages
         WHERE conversation_id = ? AND is_deleted = 0
         ORDER BY created_at DESC
         LIMIT 1`,
        [conversationId]
    );

    const [[selfParticipant]] = await mysqlPool.execute(
        `SELECT last_read
         FROM chat_conversation_participants
         WHERE conversation_id = ? AND user_id = ?
         LIMIT 1`,
        [conversationId, currentUserId]
    );

    const [unreadRows] = await mysqlPool.execute(
        `SELECT COUNT(*) AS unreadCount
         FROM chat_messages
         WHERE conversation_id = ?
           AND sender_id <> ?
           AND is_deleted = 0
           AND created_at > ?`,
        [
            conversationId,
            currentUserId,
            selfParticipant?.last_read ?? new Date(0),
        ]
    );

    return {
        _id: conversation.conversation_id,
        participants,
        participantIds,
        listingId: conversation.listing_id,
        listingTitle: conversation.listing_title,
        bookingId: conversation.booking_id,
        unreadCount: Number(unreadRows[0]?.unreadCount ?? 0),
        isActive: conversation.is_active === 1 || conversation.is_active === true,
        createdAt: conversation.created_at,
        updatedAt: conversation.updated_at,
        lastMessage: lastMessageRow
            ? {
                content: lastMessageRow.content,
                senderId: String(lastMessageRow.sender_id),
                sentAt: lastMessageRow.created_at,
            }
            : null,
    };
}

async function listSqlConversations(currentUserId) {
    await ensureMySqlChatTables();

    const [rows] = await mysqlPool.execute(
        `SELECT c.conversation_id
         FROM chat_conversations c
         INNER JOIN chat_conversation_participants p
             ON p.conversation_id = c.conversation_id
         WHERE p.user_id = ? AND c.is_active = 1
         ORDER BY c.updated_at DESC`,
        [currentUserId]
    );

    const serialized = [];
    for (const row of rows) {
        const conversation = await serializeSqlConversation(
            row.conversation_id,
            currentUserId
        );
        if (conversation) {
            serialized.push(conversation);
        }
    }
    return serialized;
}

async function listSqlMessages(conversationId, currentUserId) {
    await ensureMySqlChatTables();

    const [[membership]] = await mysqlPool.execute(
        `SELECT 1 AS has_access
         FROM chat_conversation_participants
         WHERE conversation_id = ? AND user_id = ?
         LIMIT 1`,
        [conversationId, currentUserId]
    );

    if (!membership) {
        return null;
    }

    const [participants] = await mysqlPool.execute(
        `SELECT user_id, last_read
         FROM chat_conversation_participants
         WHERE conversation_id = ?`,
        [conversationId]
    );

    const [rows] = await mysqlPool.execute(
        `SELECT message_id, conversation_id, sender_id, sender_name, sender_role, content, content_type, created_at, updated_at
         FROM chat_messages
         WHERE conversation_id = ? AND is_deleted = 0
         ORDER BY created_at ASC`,
        [conversationId]
    );

    return rows.map((message) => {
        const deliveredTo = participants
            .filter((participant) => String(participant.user_id) !== String(message.sender_id))
            .map((participant) => ({
                userId: String(participant.user_id),
                deliveredAt: message.created_at,
            }));

        const readBy = participants
            .filter((participant) => new Date(participant.last_read) >= new Date(message.created_at))
            .map((participant) => ({
                userId: String(participant.user_id),
                readAt: participant.last_read,
            }));

        const hasOtherReader = readBy.some(
            (receipt) => receipt.userId !== String(message.sender_id)
        );

        return {
            _id: String(message.message_id),
            conversationId: String(message.conversation_id),
            senderId: String(message.sender_id),
            senderName: message.sender_name,
            senderRole: message.sender_role,
            content: message.content,
            contentType: message.content_type ?? 'text',
            status: String(message.sender_id) === currentUserId
                ? (hasOtherReader ? 'read' : 'sent')
                : 'read',
            readBy,
            deliveredTo,
            createdAt: message.created_at,
            timeAgo: 'just now',
        };
    });
}

async function createSqlConversation({
    currentUserId,
    currentUserRole,
    participantId,
    listingId,
    bookingId,
    initialMessage,
}) {
    await ensureMySqlChatTables();

    const normalizedListingId = listingId ?? null;
    const normalizedBookingId = bookingId ?? null;

    const [existingRows] = await mysqlPool.execute(
        `SELECT c.conversation_id
         FROM chat_conversations c
         INNER JOIN chat_conversation_participants p1
             ON p1.conversation_id = c.conversation_id AND p1.user_id = ?
         INNER JOIN chat_conversation_participants p2
             ON p2.conversation_id = c.conversation_id AND p2.user_id = ?
         WHERE COALESCE(c.listing_id, '') = COALESCE(?, '')
           AND COALESCE(c.booking_id, '') = COALESCE(?, '')
           AND c.is_active = 1
           AND (
                SELECT COUNT(*)
                FROM chat_conversation_participants cp
                WHERE cp.conversation_id = c.conversation_id
           ) = 2
         LIMIT 1`,
        [currentUserId, String(participantId), normalizedListingId, normalizedBookingId]
    );

    let conversationId = existingRows[0]?.conversation_id;

    if (!conversationId) {
        conversationId = randomUUID();
        const now = new Date();
        const participantIds = [String(currentUserId), String(participantId)];
        const participantMeta = await getParticipantsMeta(participantIds);

        await mysqlPool.execute(
            `INSERT INTO chat_conversations
             (conversation_id, listing_id, listing_title, booking_id, is_active, created_at, updated_at)
             VALUES (?, ?, ?, ?, 1, ?, ?)`,
            [
                conversationId,
                normalizedListingId,
                await getListingTitle(normalizedListingId),
                normalizedBookingId,
                now,
                now,
            ]
        );

        for (const id of participantIds) {
            await mysqlPool.execute(
                `INSERT INTO chat_conversation_participants
                 (conversation_id, user_id, role, joined_at, last_read)
                 VALUES (?, ?, ?, ?, ?)`,
                [
                    conversationId,
                    id,
                    participantMeta.get(id)?.role ??
                        (id === String(currentUserId) ? currentUserRole : 'tourist'),
                    now,
                    id === String(currentUserId) ? now : new Date(0),
                ]
            );
        }
    }

    if (initialMessage && initialMessage.toString().trim().length > 0) {
        const now = new Date();
        await mysqlPool.execute(
            `INSERT INTO chat_messages
             (message_id, conversation_id, sender_id, sender_name, sender_role, content, content_type, is_deleted, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, 'text', 0, ?, ?)`,
            [
                randomUUID(),
                conversationId,
                String(currentUserId),
                await getUserDisplayName(currentUserId),
                currentUserRole,
                initialMessage.toString().trim(),
                now,
                now,
            ]
        );

        await mysqlPool.execute(
            `UPDATE chat_conversations
             SET updated_at = ?, listing_title = COALESCE(listing_title, ?)
             WHERE conversation_id = ?`,
            [now, await getListingTitle(normalizedListingId), conversationId]
        );

        await mysqlPool.execute(
            `UPDATE chat_conversation_participants
             SET last_read = ?
             WHERE conversation_id = ? AND user_id = ?`,
            [now, conversationId, String(currentUserId)]
        );
    }

    return serializeSqlConversation(conversationId, String(currentUserId));
}

async function sendSqlMessage(conversationId, currentUserId, currentUserRole, content, contentType) {
    await ensureMySqlChatTables();

    const [[membership]] = await mysqlPool.execute(
        `SELECT 1 AS has_access
         FROM chat_conversation_participants
         WHERE conversation_id = ? AND user_id = ?
         LIMIT 1`,
        [conversationId, currentUserId]
    );

    if (!membership) {
        return { notFound: true };
    }

    const now = new Date();
    const messageId = randomUUID();

    await mysqlPool.execute(
        `INSERT INTO chat_messages
         (message_id, conversation_id, sender_id, sender_name, sender_role, content, content_type, is_deleted, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
        [
            messageId,
            conversationId,
            String(currentUserId),
            await getUserDisplayName(currentUserId),
            currentUserRole,
            content,
            contentType ?? 'text',
            now,
            now,
        ]
    );

    await mysqlPool.execute(
        `UPDATE chat_conversations
         SET updated_at = ?
         WHERE conversation_id = ?`,
        [now, conversationId]
    );

    await mysqlPool.execute(
        `UPDATE chat_conversation_participants
         SET last_read = ?
         WHERE conversation_id = ? AND user_id = ?`,
        [now, conversationId, String(currentUserId)]
    );

    const [participants] = await mysqlPool.execute(
        `SELECT user_id
         FROM chat_conversation_participants
         WHERE conversation_id = ?`,
        [conversationId]
    );

    return {
        success: true,
        message: {
            _id: messageId,
            conversationId,
            senderId: String(currentUserId),
            senderName: await getUserDisplayName(currentUserId),
            senderRole: currentUserRole,
            content,
            contentType: contentType ?? 'text',
            status: 'sent',
            readBy: [{
                userId: String(currentUserId),
                readAt: now,
            }],
            deliveredTo: participants
                .filter((participant) => String(participant.user_id) !== String(currentUserId))
                .map((participant) => ({
                    userId: String(participant.user_id),
                    deliveredAt: now,
                })),
            createdAt: now,
            timeAgo: 'just now',
        },
    };
}

async function markSqlConversationRead(conversationId, currentUserId) {
    await ensureMySqlChatTables();

    const [[membership]] = await mysqlPool.execute(
        `SELECT 1 AS has_access
         FROM chat_conversation_participants
         WHERE conversation_id = ? AND user_id = ?
         LIMIT 1`,
        [conversationId, currentUserId]
    );

    if (!membership) {
        return false;
    }

    const now = new Date();
    await mysqlPool.execute(
        `UPDATE chat_conversation_participants
         SET last_read = ?
         WHERE conversation_id = ? AND user_id = ?`,
        [now, conversationId, String(currentUserId)]
    );

    await mysqlPool.execute(
        `UPDATE chat_conversations
         SET updated_at = ?
         WHERE conversation_id = ?`,
        [now, conversationId]
    );

    return true;
}

async function deleteSqlConversation(conversationId, currentUserId) {
    await ensureMySqlChatTables();

    const [[membership]] = await mysqlPool.execute(
        `SELECT 1 AS has_access
         FROM chat_conversation_participants
         WHERE conversation_id = ? AND user_id = ?
         LIMIT 1`,
        [conversationId, currentUserId]
    );

    if (!membership) {
        return false;
    }

    await mysqlPool.execute(
        'DELETE FROM chat_conversations WHERE conversation_id = ?',
        [conversationId]
    );

    return true;
}

router.get('/recipients', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const role = req.user.role;

        let roleFilter = '';
        const params = [currentUserId];

        if (role === 'tourist') {
            roleFilter = "AND (u.role = 'admin' OR u.role = 'vendor')";
        } else if (role === 'vendor') {
            roleFilter = "AND (u.role = 'admin' OR u.role = 'tourist')";
        }

        const [rows] = await mysqlPool.execute(
            `SELECT 
                u.user_id,
                u.full_name,
                u.role,
                u.email,
                v.business_name,
                COALESCE(v.verified, 1) AS verified
             FROM users u
             LEFT JOIN vendors v ON u.user_id = v.user_id
             WHERE u.user_id <> ?
             ${roleFilter}
             ORDER BY u.full_name ASC`,
            params
        );

        const recipients = rows
            .filter((row) => row.role !== 'vendor' || row.verified === 1 || row.verified === true)
            .map((row) => ({
                id: String(row.user_id),
                name: row.role === 'vendor' && row.business_name
                    ? row.business_name
                    : row.full_name,
                role: row.role,
                email: row.email,
            }));

        res.json({ success: true, recipients });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/conversations', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);

        if (!isMongoReady()) {
            const conversations = await listSqlConversations(currentUserId);
            return res.json({ success: true, conversations });
        }

        const { conversations } = getCollections();
        const docs = await conversations.find({
            participantIds: currentUserId,
            isActive: { $ne: false },
        }).sort({ updatedAt: -1 }).toArray();

        const serialized = [];
        for (const doc of docs) {
            serialized.push(await serializeConversation(doc, currentUserId));
        }

        res.json({ success: true, conversations: serialized });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/conversations/:conversationId/messages', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const conversationId = req.params.conversationId;

        if (!isMongoReady()) {
            const messages = await listSqlMessages(conversationId, currentUserId);
            if (messages === null) {
                return res.status(404).json({ success: false, error: 'Conversation not found' });
            }

            return res.json({ success: true, messages });
        }

        const { conversations, messages } = getCollections();
        const objectId = toObjectId(conversationId);

        if (!objectId) {
            return res.status(400).json({ success: false, error: 'Invalid conversation id' });
        }

        const conversation = await conversations.findOne({
            _id: objectId,
            participantIds: currentUserId,
            isActive: { $ne: false },
        });

        if (!conversation) {
            return res.status(404).json({ success: false, error: 'Conversation not found' });
        }

        const docs = await messages.find({
            conversationId,
            isDeleted: { $ne: true },
        }).sort({ createdAt: 1 }).toArray();

        res.json({
            success: true,
            messages: docs.map((message) => ({
                _id: String(message._id),
                conversationId: message.conversationId,
                senderId: String(message.senderId),
                senderName: message.senderName,
                senderRole: message.senderRole,
                content: message.content,
                contentType: message.contentType ?? 'text',
                status: message.senderId === currentUserId
                    ? ((message.readBy ?? []).some((id) => id !== currentUserId) ? 'read' : 'sent')
                    : 'read',
                readBy: (message.readBy ?? []).map((userId) => ({
                    userId: String(userId),
                    readAt: message.updatedAt ?? message.createdAt,
                })),
                deliveredTo: (message.deliveredTo ?? []).map((userId) => ({
                    userId: String(userId),
                    deliveredAt: message.createdAt,
                })),
                createdAt: message.createdAt,
                timeAgo: 'just now',
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/conversations', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const currentUserRole = req.user.role;
        const { participantId, listingId, bookingId, initialMessage } = req.body;

        if (!participantId) {
            return res.status(400).json({ success: false, error: 'participantId is required' });
        }

        if (!isMongoReady()) {
            const conversation = await createSqlConversation({
                currentUserId,
                currentUserRole,
                participantId,
                listingId,
                bookingId,
                initialMessage,
            });
            return res.status(201).json({ success: true, conversation });
        }

        const { conversations, messages } = getCollections();
        const participantIds = [currentUserId, String(participantId)].sort();
        let conversation = await conversations.findOne({
            participantIds,
            listingId: listingId ?? null,
            bookingId: bookingId ?? null,
            isActive: { $ne: false },
        });

        if (!conversation) {
            const now = new Date();
            const participantMeta = await getParticipantsMeta(participantIds);
            const insertResult = await conversations.insertOne({
                participantIds,
                participants: participantIds.map((id) => ({
                    userId: id,
                    role: participantMeta.get(id)?.role ?? (id === currentUserId ? currentUserRole : 'tourist'),
                    joinedAt: now,
                    lastRead: id === currentUserId ? now : new Date(0),
                })),
                listingId: listingId ?? null,
                listingTitle: await getListingTitle(listingId),
                bookingId: bookingId ?? null,
                isActive: true,
                createdAt: now,
                updatedAt: now,
            });

            conversation = await conversations.findOne({ _id: insertResult.insertedId });
        }

        if (initialMessage && initialMessage.toString().trim().length > 0) {
            const now = new Date();
            await messages.insertOne({
                conversationId: String(conversation._id),
                senderId: currentUserId,
                senderName: await getUserDisplayName(currentUserId),
                senderRole: currentUserRole,
                content: initialMessage.toString().trim(),
                contentType: 'text',
                deliveredTo: participantIds.filter((id) => id !== currentUserId),
                readBy: [currentUserId],
                createdAt: now,
                updatedAt: now,
                isDeleted: false,
            });

            await conversations.updateOne(
                { _id: conversation._id },
                {
                    $set: {
                        updatedAt: now,
                        listingTitle: conversation.listingTitle ?? await getListingTitle(listingId),
                        'participants.$[self].lastRead': now,
                    },
                },
                {
                    arrayFilters: [{ 'self.userId': currentUserId }],
                }
            );

            conversation = await conversations.findOne({ _id: conversation._id });
        }

        res.status(201).json({
            success: true,
            conversation: await serializeConversation(conversation, currentUserId),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/conversations/:conversationId/messages', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const conversationId = req.params.conversationId;
        const content = req.body.content?.toString().trim();

        if (!content) {
            return res.status(400).json({ success: false, error: 'Message content is required' });
        }

        if (!isMongoReady()) {
            const result = await sendSqlMessage(
                conversationId,
                currentUserId,
                req.user.role,
                content,
                req.body.contentType?.toString()
            );

            if (result.notFound) {
                return res.status(404).json({ success: false, error: 'Conversation not found' });
            }

            return res.status(201).json(result);
        }

        const { conversations, messages } = getCollections();
        const objectId = toObjectId(conversationId);

        if (!objectId) {
            return res.status(400).json({ success: false, error: 'Invalid conversation id' });
        }

        const conversation = await conversations.findOne({
            _id: objectId,
            participantIds: currentUserId,
            isActive: { $ne: false },
        });

        if (!conversation) {
            return res.status(404).json({ success: false, error: 'Conversation not found' });
        }

        const now = new Date();
        const participantIds = (conversation.participantIds ?? []).map(String);
        const insertResult = await messages.insertOne({
            conversationId,
            senderId: currentUserId,
            senderName: await getUserDisplayName(currentUserId),
            senderRole: req.user.role,
            content,
            contentType: req.body.contentType?.toString() ?? 'text',
            deliveredTo: participantIds.filter((id) => id !== currentUserId),
            readBy: [currentUserId],
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
        });

        await conversations.updateOne(
            { _id: objectId },
            {
                $set: {
                    updatedAt: now,
                    'participants.$[self].lastRead': now,
                },
            },
            {
                arrayFilters: [{ 'self.userId': currentUserId }],
            }
        );

        const savedMessage = await messages.findOne({ _id: insertResult.insertedId });

        res.status(201).json({
            success: true,
            message: {
                _id: String(savedMessage._id),
                conversationId: savedMessage.conversationId,
                senderId: String(savedMessage.senderId),
                senderName: savedMessage.senderName,
                senderRole: savedMessage.senderRole,
                content: savedMessage.content,
                contentType: savedMessage.contentType,
                status: 'sent',
                readBy: [{
                    userId: currentUserId,
                    readAt: savedMessage.createdAt,
                }],
                deliveredTo: (savedMessage.deliveredTo ?? []).map((userId) => ({
                    userId: String(userId),
                    deliveredAt: savedMessage.createdAt,
                })),
                createdAt: savedMessage.createdAt,
                timeAgo: 'just now',
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/conversations/:conversationId/read', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const conversationId = req.params.conversationId;

        if (!isMongoReady()) {
            const success = await markSqlConversationRead(conversationId, currentUserId);
            if (!success) {
                return res.status(404).json({ success: false, error: 'Conversation not found' });
            }
            return res.json({ success: true });
        }

        const { conversations, messages } = getCollections();
        const objectId = toObjectId(conversationId);

        if (!objectId) {
            return res.status(400).json({ success: false, error: 'Invalid conversation id' });
        }

        const conversation = await conversations.findOne({
            _id: objectId,
            participantIds: currentUserId,
            isActive: { $ne: false },
        });

        if (!conversation) {
            return res.status(404).json({ success: false, error: 'Conversation not found' });
        }

        const now = new Date();
        await messages.updateMany(
            {
                conversationId,
                senderId: { $ne: currentUserId },
                readBy: { $ne: currentUserId },
                isDeleted: { $ne: true },
            },
            {
                $addToSet: { readBy: currentUserId },
                $set: { updatedAt: now },
            }
        );

        await conversations.updateOne(
            { _id: objectId },
            {
                $set: {
                    'participants.$[self].lastRead': now,
                    updatedAt: now,
                },
            },
            {
                arrayFilters: [{ 'self.userId': currentUserId }],
            }
        );

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.delete('/conversations/:conversationId', async (req, res) => {
    try {
        const currentUserId = String(req.user.userId);
        const conversationId = req.params.conversationId;

        if (!isMongoReady()) {
            const success = await deleteSqlConversation(conversationId, currentUserId);
            if (!success) {
                return res.status(404).json({ success: false, error: 'Conversation not found' });
            }
            return res.json({ success: true });
        }

        const { conversations, messages } = getCollections();
        const objectId = toObjectId(conversationId);

        if (!objectId) {
            return res.status(400).json({ success: false, error: 'Invalid conversation id' });
        }

        const conversation = await conversations.findOne({
            _id: objectId,
            participantIds: currentUserId,
        });

        if (!conversation) {
            return res.status(404).json({ success: false, error: 'Conversation not found' });
        }

        await conversations.deleteOne({ _id: objectId });
        await messages.deleteMany({ conversationId });

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
