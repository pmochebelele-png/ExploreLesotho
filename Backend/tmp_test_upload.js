const fetch = globalThis.fetch || require('node-fetch');
(async () => {
  try {
    const loginRes = await fetch('http://127.0.0.1:3001/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'cosmo@gmail.com', password: 'password' }),
    });
    const loginData = await loginRes.json();
    console.log('login status', loginRes.status, loginData.success, loginData);
    if (!loginData.token) return;
    const token = loginData.token;
    const payload = {
      title: 'Test Upload Listing',
      description: 'Test description',
      category: 'Accommodation',
      price: 100,
      location: 'Test location',
      district: 'Test district',
      images: ['data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA'],
    };
    const createRes = await fetch('http://127.0.0.1:3001/api/listings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token,
      },
      body: JSON.stringify(payload),
    });
    const createData = await createRes.json();
    console.log('create status', createRes.status, createData);
  } catch (e) {
    console.error('error', e);
  }
})();
