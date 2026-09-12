import * as ImageManipulator from 'expo-image-manipulator';

/**
 * Compresses and resizes invoice receipt images before upload
 * Keeps file size under ~300KB to minimize Supabase Storage bandwidth and cost.
 */
export async function compressReceiptImage(uri: string): Promise<string> {
  try {
    const manipResult = await ImageManipulator.manipulateAsync(
      uri,
      [{ resize: { width: 1200 } }], // Resize max width to 1200px
      { compress: 0.7, format: ImageManipulator.SaveFormat.JPEG, base64: true }
    );
    return manipResult.uri;
  } catch (error) {
    console.warn('Image compression fallback:', error);
    return uri; // Return original uri if manipulation fails
  }
}
