import { buildUPIIntentURL, generateUPIQRCode } from '../upiIntent';

describe('UPI Intent URL Builder', () => {
  it('should format upi://pay URI correctly', () => {
    const url = buildUPIIntentURL({
      vpaId: 'kowsic@okaxis',
      payeeName: 'Kowsic L',
      amount: 150.5,
      currency: 'INR',
      note: 'Goa Trip Settlement',
    });

    expect(url).toBe('upi://pay?pa=kowsic@okaxis&pn=Kowsic%20L&am=150.50&cu=INR&tn=Goa%20Trip%20Settlement');
  });

  it('should sanitize special characters and hyphens from transaction note', () => {
    const url = buildUPIIntentURL({
      vpaId: 'test@upi',
      payeeName: 'Sam',
      amount: 27.5,
      currency: 'INR',
      note: 'FairShare Settlement - House (Cart)!',
    });

    expect(url).toBe('upi://pay?pa=test@upi&pn=Sam&am=27.50&cu=INR&tn=FairShare%20Settlement%20House%20Cart');
  });

  it('should generate scannable QR code data URL', async () => {
    const qrDataUrl = await generateUPIQRCode({
      vpaId: 'test@upi',
      payeeName: 'Sam',
      amount: 27.5,
      currency: 'INR',
    });

    expect(qrDataUrl).toBeDefined();
    expect(qrDataUrl.startsWith('data:image/png;base64,')).toBe(true);
  });
});
