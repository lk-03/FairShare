import { buildUPIIntentURL } from '../upiIntent';

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
});
