// ============================================================================
// FAIRSHARE SUPABASE EDGE FUNCTION: OCR PARSER
// ============================================================================
// Processes receipt images via Cloud Vision / OCR and returns structured line items
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { imageBase64, rawText } = await req.json();

    let extractedText = rawText || '';

    // If base64 image provided and Google Vision API Key exists
    const visionApiKey = Deno.env.get('GOOGLE_VISION_API_KEY');
    if (imageBase64 && visionApiKey) {
      const visionRes = await fetch(
        `https://vision.googleapis.com/v1/images:annotate?key=${visionApiKey}`,
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

      const visionData = await visionRes.json();
      extractedText = visionData.responses?.[0]?.fullTextAnnotation?.text || '';
    }

    // Return parsed payload
    return new Response(
      JSON.stringify({
        success: true,
        rawText: extractedText,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
