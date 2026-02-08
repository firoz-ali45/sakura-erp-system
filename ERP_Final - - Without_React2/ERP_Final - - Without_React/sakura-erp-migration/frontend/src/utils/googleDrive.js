/**
 * Google Drive Document Viewer Utility
 * Converts Google Drive file URLs to preview URLs for iframe embedding
 */

/**
 * Convert Google Drive file URL to preview URL
 * From: https://drive.google.com/file/d/FILE_ID/view
 * To: https://drive.google.com/file/d/FILE_ID/preview
 * 
 * @param {string} url - Google Drive file URL
 * @returns {string} Preview URL for iframe embedding
 */
export function convertToGoogleDrivePreview(url) {
  if (!url || typeof url !== 'string') {
    return url;
  }

  // Extract file ID from various Google Drive URL formats
  let fileId = '';
  
  // Pattern 1: https://drive.google.com/file/d/FILE_ID/view
  const viewMatch = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (viewMatch) {
    fileId = viewMatch[1];
  }
  
  // Pattern 2: https://drive.google.com/open?id=FILE_ID
  const openMatch = url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (openMatch && !fileId) {
    fileId = openMatch[1];
  }
  
  // Pattern 3: https://docs.google.com/document/d/FILE_ID/edit
  const docsMatch = url.match(/\/document\/d\/([a-zA-Z0-9_-]+)/);
  if (docsMatch && !fileId) {
    fileId = docsMatch[1];
    return `https://docs.google.com/document/d/${fileId}/preview`;
  }
  
  // Pattern 4: https://docs.google.com/spreadsheets/d/FILE_ID/edit
  const sheetsMatch = url.match(/\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/);
  if (sheetsMatch && !fileId) {
    fileId = sheetsMatch[1];
    return `https://docs.google.com/spreadsheets/d/${fileId}/preview`;
  }
  
  // Pattern 5: https://docs.google.com/presentation/d/FILE_ID/edit
  const slidesMatch = url.match(/\/presentation\/d\/([a-zA-Z0-9_-]+)/);
  if (slidesMatch && !fileId) {
    fileId = slidesMatch[1];
    return `https://docs.google.com/presentation/d/${fileId}/preview`;
  }
  
  // If already a preview URL, return as is
  if (url.includes('/preview')) {
    return url;
  }
  
  // If we have a file ID, convert to preview URL
  if (fileId) {
    return `https://drive.google.com/file/d/${fileId}/preview`;
  }
  
  // If we can't parse it, return original URL
  return url;
}

/**
 * Create iframe element for Google Drive document preview
 * 
 * @param {string} previewUrl - Preview URL from convertToGoogleDrivePreview
 * @param {Object} options - Optional iframe attributes
 * @returns {HTMLIFrameElement} Configured iframe element
 */
export function createGoogleDriveIframe(previewUrl, options = {}) {
  const iframe = document.createElement('iframe');
  
  iframe.src = convertToGoogleDrivePreview(previewUrl);
  iframe.width = options.width || '100%';
  iframe.height = options.height || '100%';
  iframe.setAttribute('allow', options.allow || 'autoplay');
  iframe.setAttribute('sandbox', options.sandbox || 'allow-scripts allow-same-origin allow-popups');
  iframe.style.border = options.border || 'none';
  iframe.style.display = 'block';
  
  if (options.frameBorder) {
    iframe.frameBorder = options.frameBorder;
  }
  
  if (options.scrolling) {
    iframe.scrolling = options.scrolling;
  }
  
  if (options.id) {
    iframe.id = options.id;
  }
  
  if (options.className) {
    iframe.className = options.className;
  }
  
  return iframe;
}

/**
 * Check if URL is a Google Drive URL
 * 
 * @param {string} url - URL to check
 * @returns {boolean} True if URL is a Google Drive URL
 */
export function isGoogleDriveUrl(url) {
  if (!url || typeof url !== 'string') {
    return false;
  }
  
  return url.includes('drive.google.com') || 
         url.includes('docs.google.com') ||
         url.includes('googledrive.com');
}
