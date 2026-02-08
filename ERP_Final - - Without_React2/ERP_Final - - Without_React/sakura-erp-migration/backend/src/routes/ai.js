/**
 * AI Intent Resolution Route
 * Server-side Gemini API gateway
 * NEVER exposes API key to frontend
 */

import express from 'express';
import { body, validationResult } from 'express-validator';

const router = express.Router();

// API key must be set in environment variables for production
// NEVER expose API key in code - use .env file
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || 'AIzaSyAv1IEyCWng9fx_NTlB4c0ij4OZrBuaeGQ';
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';

/**
 * POST /api/ai/resolve-intent
 * Resolve user intent using Gemini API (server-side only)
 * 
 * Request body:
 * {
 *   question: string,
 *   context: {
 *     modules: Array,
 *     data: Object,
 *     user: Object
 *   }
 * }
 * 
 * Response:
 * {
 *   success: boolean,
 *   data: {
 *     intent: string,
 *     module: string | null,
 *     metric: string | null,
 *     entity: string | null
 *   },
 *   error?: string
 * }
 */
router.post('/resolve-intent', [
  body('question').notEmpty().withMessage('Question is required'),
  body('context').isObject().withMessage('Context is required')
], async (req, res, next) => {
  try {
    // Validate request
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        errors: errors.array()
      });
    }

    const { question, context } = req.body;

    // Validate Gemini API key
    if (!GEMINI_API_KEY || GEMINI_API_KEY === '') {
      console.error('GEMINI_API_KEY is not set in environment variables');
      return res.status(500).json({
        success: false,
        error: 'AI service configuration error'
      });
    }

    // Build available modules list from context (dynamic - no hardcoding)
    const availableModules = (context.modules || [])
      .filter(m => m.route)
      .map(m => ({
        id: m.id,
        label: m.label || m.id,
        route: m.route,
        dataSource: m.dataSource || 'Supabase'
      }));

    // Build available metrics/entities from context data (dynamic)
    const availableMetrics = [];
    Object.keys(context.data || {}).forEach(moduleId => {
      const moduleData = context.data[moduleId];
      if (moduleData) {
        if (moduleData.count !== undefined) {
          availableMetrics.push(`${moduleId}.count`);
        }
        if (moduleData.metrics) {
          Object.keys(moduleData.metrics).forEach(metric => {
            availableMetrics.push(`${moduleId}.${metric}`);
          });
        }
        if (moduleData.totalDues !== undefined) {
          availableMetrics.push(`${moduleId}.totalDues`);
        }
        if (moduleData.totalBudget !== undefined) {
          availableMetrics.push(`${moduleId}.totalBudget`);
        }
        if (moduleData.inventoryValue !== undefined) {
          availableMetrics.push(`${moduleId}.inventoryValue`);
        }
      }
    });

    // Build system prompt (MANDATORY - strict format)
    const systemPrompt = `You are Sakura ERP AI Intent Resolver.
Return ONLY valid JSON.
Do NOT explain.
Do NOT add text.
Do NOT use markdown.

You MUST map the user question to:
- intent: one of: get_user_name, get_inventory_count, get_suppliers_count, get_purchase_orders_count, get_transfer_orders_count, get_grns_count, get_users_count, get_accounts_payable, get_rm_forecasting, get_warehouse_dashboard, get_module_list, get_module_data, unknown
- module: the module ID from available modules (e.g., "items", "suppliers", "purchase-orders", "transfer-orders", "grns", "user-management", "accounts-payable", "rm-forecasting", "warehouse-dashboard")
- metric: the specific metric requested (e.g., "count", "totalDues", "lowStock", "pending", "completed", "inventoryValue", "totalBudget")
- entity: optional, specific entity name if mentioned (e.g., item name, supplier name)

Available modules: ${JSON.stringify(availableModules.map(m => ({ id: m.id, label: m.label })))}

Available metrics: ${availableMetrics.join(', ')}

User context: ${context.user ? JSON.stringify({ name: context.user.name, role: context.user.role }) : 'No user logged in'}

If the question cannot be mapped to any module or metric, return:
{"intent": "unknown"}

Return ONLY valid JSON, no markdown, no code blocks, no explanations.`;

    // Build full prompt
    const fullPrompt = `${systemPrompt}

USER QUESTION:
${question}

Return JSON only:`;

    // Call Gemini API (SERVER-SIDE ONLY)
    const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{
          role: 'user',
          parts: [{
            text: fullPrompt
          }]
        }],
        generationConfig: {
          temperature: 0,
          maxOutputTokens: 256
        }
      })
    });

    // HARD ASSERTION: Check response status
    if (!response.ok) {
      const errorText = await response.text();
      let errorJson;
      try {
        errorJson = JSON.parse(errorText);
      } catch {
        errorJson = { error: { message: errorText } };
      }
      console.error('Gemini API error:', response.status, errorJson);
      return res.status(502).json({
        success: false,
        error: 'AI service temporarily unavailable',
        details: process.env.NODE_ENV === 'development' ? errorJson : undefined
      });
    }

    // Parse Gemini response
    const json = await response.json();
    
    // HARD ASSERTION: Extract text from response
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    
    if (!text) {
      console.error('Gemini API returned empty text:', json);
      return res.status(502).json({
        success: false,
        error: 'AI service returned invalid response'
      });
    }

    // Extract and parse JSON from text response
    let intentJson = null;
    
    try {
      // Remove markdown code blocks if present
      const cleanedText = text
        .replace(/```json\n?/g, '')
        .replace(/```\n?/g, '')
        .trim();
      
      intentJson = JSON.parse(cleanedText);
    } catch (parseError) {
      console.error('Failed to parse Gemini JSON response. Raw text:', text);
      // Try to extract JSON object from text as fallback
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          intentJson = JSON.parse(jsonMatch[0]);
        } catch (matchParseError) {
          return res.status(502).json({
            success: false,
            error: 'AI service returned invalid format',
            details: process.env.NODE_ENV === 'development' ? text.substring(0, 200) : undefined
          });
        }
      } else {
        return res.status(502).json({
          success: false,
          error: 'AI service returned invalid format',
          details: process.env.NODE_ENV === 'development' ? text.substring(0, 200) : undefined
        });
      }
    }

    // Validate intent structure
    if (!intentJson || typeof intentJson !== 'object') {
      return res.status(502).json({
        success: false,
        error: 'AI service returned invalid intent structure'
      });
    }

    // Ensure intent field exists
    if (!intentJson.intent) {
      intentJson.intent = 'unknown';
    }

    // Return structured data (NO text responses)
    res.json({
      success: true,
      data: {
        intent: intentJson.intent,
        module: intentJson.module || null,
        metric: intentJson.metric || null,
        entity: intentJson.entity || null
      }
    });

  } catch (error) {
    console.error('Error in AI intent resolution:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error during AI processing',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

export default router;
