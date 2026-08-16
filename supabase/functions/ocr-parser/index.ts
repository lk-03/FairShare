import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const GOOGLE_VISION_API_KEY = Deno.env.get('GOOGLE_CLOUD_VISION_API_KEY') || '';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const { imageBase64 } = await req.json();

    if (!imageBase64) {
      return new Response(JSON.stringify({ error: 'Missing imageBase64 payload' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!GOOGLE_VISION_API_KEY) {
      // Return structured mock parsing if API key is not configured yet
      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          title: 'Invoice / Receipt',
          totalAmount: 1450.0,
          date: new Date().toISOString().split('T')[0],
          lineItems: [
            { id: '1', title: 'Line Item 1', price: 900.0, quantity: 1, assignedUserIds: [] },
            { id: '2', title: 'Line Item 2', price: 550.0, quantity: 1, assignedUserIds: [] },
          ],
        }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Call Google Cloud Vision API DOCUMENT_TEXT_DETECTION
    const response = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${GOOGLE_VISION_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requests: [
            {
              image: { content: imageBase64 },
              features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
            },
          ],
        }),
      }
    );

    const visionData = await response.json();
    const fullText = visionData.responses?.[0]?.fullTextAnnotation?.text || '';

    // Basic regex extraction for total amount and lines
    const amountMatches = fullText.match(/(?:total|amount|rs|₹|\$)\s*:?\s*(\d+(?:\.\d{2})?)/i);
    const parsedTotal = amountMatches ? parseFloat(amountMatches[1]) : 0;

    return new Response(
      JSON.stringify({
        success: true,
        fullText,
        totalAmount: parsedTotal,
        date: new Date().toISOString().split('T')[0],
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
