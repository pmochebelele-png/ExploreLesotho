function smtpConfigured() {
    return Boolean(
        process.env.SMTP_HOST &&
        process.env.SMTP_PORT &&
        process.env.SMTP_USER &&
        process.env.SMTP_PASS
    );
}

function loadNodemailer() {
    try {
        return require('nodemailer');
    } catch (error) {
        console.warn('Email sending disabled: nodemailer is not installed.');
        return null;
    }
}

async function sendEmail({ to, subject, text, html }) {
    if (!smtpConfigured()) {
        console.warn('Email sending skipped: SMTP variables are not configured.');
        return false;
    }

    const nodemailer = loadNodemailer();
    if (!nodemailer) return false;

    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
        },
    });

    await transporter.sendMail({
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to,
        subject,
        text,
        html,
    });

    return true;
}

function verificationEmail({ name, code }) {
    const safeName = name || 'there';
    return {
        subject: 'Verify your Explore Lesotho account',
        text:
            `Hello ${safeName},\n\n` +
            `Your Explore Lesotho verification code is: ${code}\n\n` +
            'Enter this code in the app to verify your account.',
        html:
            `<p>Hello ${safeName},</p>` +
            `<p>Your Explore Lesotho verification code is:</p>` +
            `<h2>${code}</h2>` +
            '<p>Enter this code in the app to verify your account.</p>',
    };
}

function passwordResetEmail({ name, code }) {
    const safeName = name || 'there';
    return {
        subject: 'Reset your Explore Lesotho password',
        text:
            `Hello ${safeName},\n\n` +
            `Your Explore Lesotho password reset code is: ${code}\n\n` +
            'This code expires in 15 minutes.',
        html:
            `<p>Hello ${safeName},</p>` +
            `<p>Your Explore Lesotho password reset code is:</p>` +
            `<h2>${code}</h2>` +
            '<p>This code expires in 15 minutes.</p>',
    };
}

module.exports = {
    sendEmail,
    verificationEmail,
    passwordResetEmail,
};
