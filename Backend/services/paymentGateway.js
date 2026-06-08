const configuredProvider = (process.env.PAYMENT_PROVIDER || 'mpesa_openapi').trim().toLowerCase();
const crypto = require('crypto');

const providerName = () => configuredProvider || 'not_configured';

function providerErrorMessage(status, body) {
    const detail =
        body.message ||
        body.error ||
        body.output_ResponseDesc ||
        body.output_ResponseCode ||
        body.output_Error ||
        body.output_error ||
        body.raw;
    if (!detail) {
        return `Provider returned ${status}`;
    }
    return `Provider returned ${status}: ${String(detail).slice(0, 500)}`;
}

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
        console.error('Payment provider request failed', { url, status: response.status, body });
        const message = providerErrorMessage(response.status, body);
        throw new Error(message);
    }

    return body;
}

async function getJson(url, headers = {}) {
    const response = await fetch(url, {
        method: 'GET',
        headers: {
            Accept: 'application/json',
            ...headers,
        },
    });

    const text = await response.text();
    let body = {};
    try {
        body = text ? JSON.parse(text) : {};
    } catch (_) {
        body = { raw: text };
    }

    if (!response.ok) {
        console.error('Payment provider request failed', { url, status: response.status, body });
        const message = providerErrorMessage(response.status, body);
        throw new Error(message);
    }

    return body;
}

function mpesaBaseUrl() {
    return (process.env.MPESA_BASE_URL || 'https://openapi.m-pesa.com').replace(/\/$/, '');
}

function paypalBaseUrl() {
    const environment = (process.env.PAYPAL_ENV || 'sandbox').trim().toLowerCase();
    const fallback = environment === 'live'
        ? 'https://api-m.paypal.com'
        : 'https://api-m.sandbox.paypal.com';
    return (process.env.PAYPAL_BASE_URL || fallback).replace(/\/$/, '');
}

function paypalCredentials() {
    const clientId = process.env.PAYPAL_CLIENT_ID?.trim();
    const clientSecret = process.env.PAYPAL_CLIENT_SECRET?.trim();
    if (!clientId || !clientSecret) {
        throw new Error(
            'PayPal is not configured. Add PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET to Railway Variables.'
        );
    }
    return { clientId, clientSecret };
}

async function getPaypalAccessToken() {
    const { clientId, clientSecret } = paypalCredentials();
    const response = await fetch(`${paypalBaseUrl()}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
            Accept: 'application/json',
            'Accept-Language': 'en_US',
            Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
    });

    const body = await response.json().catch(() => ({}));
    if (!response.ok || !body.access_token) {
        throw new Error(providerErrorMessage(response.status, body));
    }
    return body.access_token;
}

function paypalCharge({ amount, currency }) {
    const originalCurrency = String(currency || 'LSL').trim().toUpperCase();
    const configuredCurrency = String(process.env.PAYPAL_CURRENCY || 'USD')
        .trim()
        .toUpperCase();

    if (originalCurrency !== 'LSL') {
        return {
            amount: Number(amount).toFixed(2),
            currency: originalCurrency,
            exchangeRate: 1,
        };
    }

    const lslPerUnit = Number(process.env.PAYPAL_LSL_PER_UNIT || process.env.PAYPAL_LSL_PER_USD);
    if (!Number.isFinite(lslPerUnit) || lslPerUnit <= 0) {
        throw new Error(
            'PAYPAL_LSL_PER_UNIT is required to convert LSL to the configured PayPal currency.'
        );
    }

    return {
        amount: (Number(amount) / lslPerUnit).toFixed(2),
        currency: configuredCurrency,
        exchangeRate: lslPerUnit,
    };
}

async function initiatePaypalPayment({
    amount,
    currency,
    reference,
    description,
}) {
    const accessToken = await getPaypalAccessToken();
    const charge = paypalCharge({ amount, currency });
    const response = await postJson(
        `${paypalBaseUrl()}/v2/checkout/orders`,
        {
            intent: 'CAPTURE',
            purchase_units: [
                {
                    reference_id: reference,
                    custom_id: reference,
                    description: String(description || 'Explore Lesotho payment').slice(0, 127),
                    amount: {
                        currency_code: charge.currency,
                        value: charge.amount,
                    },
                },
            ],
            application_context: {
                brand_name: 'Explore Lesotho',
                landing_page: 'LOGIN',
                user_action: 'PAY_NOW',
                return_url:
                    process.env.PAYPAL_RETURN_URL ||
                    `${process.env.CLIENT_URL || 'http://localhost:8080'}/#/payment-return`,
                cancel_url:
                    process.env.PAYPAL_CANCEL_URL ||
                    `${process.env.CLIENT_URL || 'http://localhost:8080'}/#/payment-cancelled`,
            },
        },
        {
            Authorization: `Bearer ${accessToken}`,
            'PayPal-Request-Id': reference,
        }
    );

    const approvalUrl = response.links?.find((link) => link.rel === 'approve')?.href;
    if (!response.id || !approvalUrl) {
        throw new Error('PayPal did not return an order ID and approval link.');
    }

    return {
        configured: true,
        provider: 'paypal',
        status: 'approval_required',
        providerReference: response.id,
        approvalUrl,
        customerMessage: 'Continue to PayPal to approve this payment.',
        raw: {
            order: response,
            charge,
            originalAmount: Number(amount).toFixed(2),
            originalCurrency: String(currency || 'LSL').toUpperCase(),
        },
    };
}

async function capturePaypalPayment(orderId) {
    const accessToken = await getPaypalAccessToken();
    const response = await postJson(
        `${paypalBaseUrl()}/v2/checkout/orders/${encodeURIComponent(orderId)}/capture`,
        {},
        {
            Authorization: `Bearer ${accessToken}`,
            'PayPal-Request-Id': `capture-${orderId}`,
        }
    );
    const capture = response.purchase_units?.[0]?.payments?.captures?.[0];
    const completed = response.status === 'COMPLETED' && capture?.status === 'COMPLETED';

    return {
        provider: 'paypal',
        status: completed ? 'paid' : 'pending',
        providerReference: capture?.id || response.id || orderId,
        orderId: response.id || orderId,
        raw: response,
    };
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
    const trimmed = value.trim().replace(/^['"]|['"]$/g, '').replace(/\\n/g, '\n');
    if (trimmed.includes('BEGIN PUBLIC KEY')) return trimmed;
    const body = trimmed.replace(/\s+/g, '');
    const wrapped = body.match(/.{1,64}/g)?.join('\n') || body;
    return `-----BEGIN PUBLIC KEY-----\n${wrapped}\n-----END PUBLIC KEY-----`;
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

    const apiKey =
        process.env.MPESA_APPLICATION_KEY ||
        process.env.MPESA_API_KEY ||
        process.env.API_KEY;
    if (!apiKey) {
        throw new Error('MPESA_APPLICATION_KEY is missing. Create an M-Pesa OpenAPI app and add the key to env.');
    }

    const encryptedApiKey = encryptWithMpesaPublicKey(apiKey);
    const response = await getJson(
        mpesaUrl('session'),
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
        process.env.MPESA_ORGANIZATION_CODE ||
        process.env.MERCHANT_CODE;
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
    const paid = responseCode === 'INS-0';
    const accepted = paid || /success|processed|pending/i.test(String(responseDesc || ''));
    const providerReference =
        response.output_TransactionID ||
        response.output_ConversationID ||
        response.output_ThirdPartyConversationID ||
        payload.input_ThirdPartyConversationID ||
        reference;

    return {
        configured: true,
        provider: 'mpesa_openapi',
        status: paid ? 'paid' : accepted ? 'pending' : 'failed',
        providerReference,
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

    if (method === 'paypal') {
        return initiatePaypalPayment({
            amount,
            currency,
            reference,
            description,
        });
    }

    if (method !== 'mpesa') {
        throw new Error('Unsupported payment method.');
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
    const callbackPayload =
        payload.Body?.stkCallback ||
        payload.body?.stkCallback ||
        payload.data ||
        payload;
    const status = String(
        callbackPayload.status ||
            callbackPayload.payment_status ||
            callbackPayload.ResultDesc ||
            callbackPayload.output_ResponseDesc ||
            callbackPayload.result ||
            ''
    ).toLowerCase();

    const paid =
        status === 'paid' ||
        status === 'success' ||
        status === 'successful' ||
        callbackPayload.ResultCode === 0 ||
        callbackPayload.result_code === 0 ||
        callbackPayload.output_ResponseCode === 'INS-0';

    const failed =
        status === 'failed' ||
        status === 'cancelled' ||
        status === 'canceled' ||
        status === 'timeout' ||
        callbackPayload.ResultCode > 0 ||
        callbackPayload.result_code > 0;

    return {
        reference:
            callbackPayload.reference ||
            callbackPayload.external_reference ||
            callbackPayload.transaction_reference ||
            callbackPayload.MerchantRequestID ||
            callbackPayload.CheckoutRequestID ||
            callbackPayload.input_ThirdPartyConversationID ||
            callbackPayload.output_ThirdPartyConversationID ||
            callbackPayload.paymentId ||
            callbackPayload.payment_id,
        providerReference:
            callbackPayload.transaction_id ||
            callbackPayload.receipt ||
            callbackPayload.MpesaReceiptNumber ||
            callbackPayload.output_TransactionID ||
            callbackPayload.output_ConversationID ||
            callbackPayload.provider_reference,
        status: paid ? 'paid' : failed ? 'failed' : 'pending',
        raw: payload,
    };
}

module.exports = {
    initiatePayment,
    capturePaypalPayment,
    normalizeCallback,
    providerName,
};
