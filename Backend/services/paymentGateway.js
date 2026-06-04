const configuredProvider = (process.env.PAYMENT_PROVIDER || '').trim().toLowerCase();
const crypto = require('crypto');

const providerName = () => configuredProvider || 'not_configured';

async function postJson(url, payload, headers = {}) {
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
            ...headers,
        },
        body: JSON.stringify(payload),
    });

    const text = await response.text();
    let body = {};
    try {
        body = text ? JSON.parse(text) : {};
    } catch (_) {
        body = { raw: text };
    }

    if (!response.ok) {
        const message = body.message || body.error || `Provider returned ${response.status}`;
        throw new Error(message);
    }

    return body;
}

function mpesaBaseUrl() {
    return (process.env.MPESA_BASE_URL || 'https://openapi.m-pesa.com').replace(/\/$/, '');
}

function mpesaEnvironment() {
    return (process.env.MPESA_ENV || 'sandbox').trim().toLowerCase() === 'openapi'
        ? 'openapi'
        : 'sandbox';
}

function mpesaMarket() {
    return (process.env.MPESA_MARKET || 'vodacomLES').trim();
}

function mpesaUrl(pathType) {
    const env = mpesaEnvironment();
    const market = mpesaMarket();
    const configured =
        pathType === 'session'
            ? process.env.MPESA_SESSION_URL
            : process.env.MPESA_C2B_URL;
    if (configured) return configured;

    const path =
        pathType === 'session'
            ? `/${env}/ipg/v2/${market}/getSession/`
            : `/${env}/ipg/v2/${market}/c2bPayment/singleStage/`;
    return `${mpesaBaseUrl()}${path}`;
}

function normalizePem(value) {
    if (!value) return '';
    const trimmed = value.trim().replace(/\\n/g, '\n');
    if (trimmed.includes('BEGIN PUBLIC KEY')) return trimmed;
    return `-----BEGIN PUBLIC KEY-----\n${trimmed}\n-----END PUBLIC KEY-----`;
}

function encryptWithMpesaPublicKey(value) {
    const publicKey = normalizePem(process.env.MPESA_PUBLIC_KEY);
    if (!publicKey) {
        throw new Error('MPESA_PUBLIC_KEY is missing. Add it to Backend/.env and Railway Variables.');
    }

    return crypto
        .publicEncrypt(
            {
                key: publicKey,
                padding: crypto.constants.RSA_PKCS1_PADDING,
            },
            Buffer.from(String(value), 'utf8')
        )
        .toString('base64');
}

let cachedMpesaSession = null;

async function getMpesaSessionKey() {
    if (cachedMpesaSession && cachedMpesaSession.expiresAt > Date.now()) {
        return cachedMpesaSession.encryptedSessionKey;
    }

    const apiKey = process.env.MPESA_APPLICATION_KEY || process.env.MPESA_API_KEY;
    if (!apiKey) {
        throw new Error('MPESA_APPLICATION_KEY is missing. Create an M-Pesa OpenAPI app and add the key to env.');
    }

    const encryptedApiKey = encryptWithMpesaPublicKey(apiKey);
    const response = await postJson(
        mpesaUrl('session'),
        {},
        {
            Authorization: `Bearer ${encryptedApiKey}`,
            Origin: process.env.MPESA_ORIGIN || '*',
        }
    );

    const sessionId =
        response.output_SessionID ||
        response.output_session_id ||
        response.sessionId ||
        response.session_id ||
        response.SessionID;
    if (!sessionId) {
        throw new Error('M-Pesa did not return output_SessionID while generating a session key.');
    }

    const encryptedSessionKey = encryptWithMpesaPublicKey(sessionId);
    cachedMpesaSession = {
        encryptedSessionKey,
        expiresAt: Date.now() + Number(process.env.MPESA_SESSION_CACHE_MS || 45 * 60 * 1000),
    };
    return encryptedSessionKey;
}

function normalizePhoneForMpesa(phone) {
    const digits = String(phone || '').replace(/\D/g, '');
    if (!digits) return digits;
    if (digits.startsWith('266')) return digits;
    if (digits.length === 8) return `266${digits}`;
    return digits;
}

async function initiateMpesaOpenApiPayment({
    amount,
    currency,
    phone,
    reference,
    description,
}) {
    const serviceProviderCode =
        process.env.MPESA_SERVICE_PROVIDER_CODE ||
        process.env.MPESA_SHORT_CODE ||
        process.env.MPESA_ORGANIZATION_CODE;
    if (!serviceProviderCode) {
        throw new Error('MPESA_SERVICE_PROVIDER_CODE is missing. Add your M-Pesa organisation shortcode to env.');
    }

    const encryptedSessionKey = await getMpesaSessionKey();
    const payload = {
        input_Amount: Number(amount).toFixed(2),
        input_CustomerMSISDN: normalizePhoneForMpesa(phone),
        input_Country: process.env.MPESA_COUNTRY || 'LES',
        input_Currency: currency || process.env.MPESA_CURRENCY || 'LSL',
        input_ServiceProviderCode: serviceProviderCode,
        input_TransactionReference: reference.replace(/[^0-9A-Za-z]/g, '').slice(0, 20),
        input_ThirdPartyConversationID: reference.replace(/[^0-9A-Za-z]/g, '').slice(0, 40),
        input_PurchasedItemsDesc: String(description || 'Explore Lesotho payment').slice(0, 256),
    };

    const response = await postJson(
        mpesaUrl('c2b'),
        payload,
        {
            Authorization: `Bearer ${encryptedSessionKey}`,
            Origin: process.env.MPESA_ORIGIN || '*',
        }
    );

    const responseCode = String(response.output_ResponseCode || response.responseCode || '').toUpperCase();
    const responseDesc = response.output_ResponseDesc || response.responseDesc || response.message;
    const accepted = responseCode === 'INS-0' || /success|processed|pending/i.test(String(responseDesc || ''));

    return {
        configured: true,
        provider: 'mpesa_openapi',
        status: accepted ? 'pending' : 'failed',
        providerReference:
            payload.input_ThirdPartyConversationID ||
            response.output_TransactionID ||
            response.output_ConversationID ||
            response.output_ThirdPartyConversationID ||
            reference,
        customerMessage:
            responseDesc ||
            'M-Pesa request sent. Enter your PIN on the official phone prompt.',
        raw: {
            request: payload,
            response,
        },
    };
}

async function initiatePayment({
    amount,
    currency,
    phone,
    reference,
    description,
    callbackUrl,
    method,
}) {
    if (!configuredProvider) {
        return {
            configured: false,
            provider: providerName(),
            status: 'provider_not_configured',
            message:
                'Payment provider is not configured. Add real provider credentials in Railway Variables before accepting live payments.',
        };
    }

    if (configuredProvider === 'monopay') {
        const apiUrl = process.env.MONOPAY_INITIATE_URL;
        const apiKey = process.env.MONOPAY_API_KEY;
        if (!apiUrl || !apiKey) {
            throw new Error('MonoPay is selected, but MONOPAY_INITIATE_URL or MONOPAY_API_KEY is missing.');
        }

        const response = await postJson(
            apiUrl,
            {
                amount,
                currency,
                phone,
                reference,
                description,
                callback_url: callbackUrl,
                payment_method: method,
            },
            { Authorization: `Bearer ${apiKey}` }
        );

        return {
            configured: true,
            provider: 'monopay',
            status: response.status || 'pending',
            providerReference:
                response.transaction_id || response.reference || response.id || reference,
            customerMessage:
                response.customer_message ||
                response.message ||
                'Payment request sent. Confirm it on your phone.',
            raw: response,
        };
    }

    if (configuredProvider === 'mpesa_daraja') {
        const initiateUrl = process.env.MPESA_INITIATE_URL;
        const accessToken = process.env.MPESA_ACCESS_TOKEN;
        if (!initiateUrl || !accessToken) {
            throw new Error('M-Pesa Daraja is selected, but MPESA_INITIATE_URL or MPESA_ACCESS_TOKEN is missing.');
        }

        const response = await postJson(
            initiateUrl,
            {
                amount,
                phone,
                reference,
                description,
                callback_url: callbackUrl,
            },
            { Authorization: `Bearer ${accessToken}` }
        );

        return {
            configured: true,
            provider: 'mpesa_daraja',
            status: response.status || 'pending',
            providerReference:
                response.CheckoutRequestID || response.transaction_id || response.reference || reference,
            customerMessage:
                response.CustomerMessage ||
                response.message ||
                'M-Pesa request sent. Enter your PIN on the official phone prompt.',
            raw: response,
        };
    }

    if (configuredProvider === 'mpesa_openapi') {
        return initiateMpesaOpenApiPayment({
            amount,
            currency,
            phone,
            reference,
            description,
            callbackUrl,
            method,
        });
    }

    throw new Error(`Unsupported PAYMENT_PROVIDER: ${configuredProvider}`);
}

function normalizeCallback(payload) {
    const status = String(
        payload.status ||
            payload.payment_status ||
            payload.ResultDesc ||
            payload.output_ResponseDesc ||
            payload.result ||
            ''
    ).toLowerCase();

    const paid =
        status === 'paid' ||
        status === 'success' ||
        status === 'successful' ||
        payload.ResultCode === 0 ||
        payload.result_code === 0 ||
        payload.output_ResponseCode === 'INS-0';

    const failed =
        status === 'failed' ||
        status === 'cancelled' ||
        status === 'canceled' ||
        status === 'timeout' ||
        payload.ResultCode > 0 ||
        payload.result_code > 0;

    return {
        reference:
            payload.reference ||
            payload.external_reference ||
            payload.transaction_reference ||
            payload.MerchantRequestID ||
            payload.CheckoutRequestID ||
            payload.input_ThirdPartyConversationID ||
            payload.output_ThirdPartyConversationID ||
            payload.paymentId ||
            payload.payment_id,
        providerReference:
            payload.transaction_id ||
            payload.receipt ||
            payload.MpesaReceiptNumber ||
            payload.output_TransactionID ||
            payload.output_ConversationID ||
            payload.provider_reference,
        status: paid ? 'paid' : failed ? 'failed' : 'pending',
        raw: payload,
    };
}

module.exports = {
    initiatePayment,
    normalizeCallback,
    providerName,
};
