const configuredProvider = (process.env.PAYMENT_PROVIDER || '').trim().toLowerCase();

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

    throw new Error(`Unsupported PAYMENT_PROVIDER: ${configuredProvider}`);
}

function normalizeCallback(payload) {
    const status = String(
        payload.status ||
            payload.payment_status ||
            payload.ResultDesc ||
            payload.result ||
            ''
    ).toLowerCase();

    const paid =
        status === 'paid' ||
        status === 'success' ||
        status === 'successful' ||
        payload.ResultCode === 0 ||
        payload.result_code === 0;

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
            payload.paymentId ||
            payload.payment_id,
        providerReference:
            payload.transaction_id ||
            payload.receipt ||
            payload.MpesaReceiptNumber ||
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
