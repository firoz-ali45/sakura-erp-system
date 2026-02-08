/**
 * AI Intent Resolver Service (Frontend)
 * Calls backend server-side Gemini API gateway
 * NEVER calls Gemini API directly from frontend
 * API key is stored securely on server only
 */

import api from './api.js';

/**
 * Resolve user intent via backend API (server-side Gemini)
 * @param {string} userMessage - User's question/message
 * @param {Object} context - Full system context (modules + data)
 * @returns {Promise<Object>} Structured intent object
 */
export async function resolveIntentWithGemini(userMessage, context) {
  try {
    // Call backend API endpoint (server handles Gemini API)
    const response = await api.post('/ai/resolve-intent', {
      question: userMessage,
      context: context
    });

    // HARD ASSERTION: Check response structure
    if (!response.data || !response.data.success) {
      throw new Error(response.data?.error || 'Backend AI service returned invalid response');
    }

    // Extract intent data from backend response
    const intentData = response.data.data;
    
    if (!intentData || !intentData.intent) {
      throw new Error('Backend AI service returned invalid intent structure');
    }

    return {
      intent: intentData.intent,
      module: intentData.module || null,
      metric: intentData.metric || null,
      entity: intentData.entity || null
    };

  } catch (error) {
    // HARD ASSERTION: Log error and re-throw (do NOT silently return unknown)
    console.error('Error resolving intent via backend API:', error);
    console.error('Full error details:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status,
      userMessage: userMessage.substring(0, 100)
    });
    
    // Re-throw error - let aiChatbotService handle it with professional ERP message
    if (error.response?.status === 502 || error.response?.status === 503) {
      throw new Error('AI service temporarily unavailable');
    } else if (error.response?.status === 500) {
      throw new Error('AI service internal error');
    } else {
      throw new Error(`Intent resolution failed: ${error.message}`);
    }
  }
}
