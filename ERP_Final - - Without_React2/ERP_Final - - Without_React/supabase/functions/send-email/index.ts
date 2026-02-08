// Supabase Edge Function to send emails via SendGrid
// This function runs server-side, so no CORS issues!

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY') || 'J-tx9kyPSHeAwxl6GNkDfw'
const SENDGRID_FROM_EMAIL = Deno.env.get('SENDGRID_FROM_EMAIL') || 'sakurapersonal071@gmail.com'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get request body
    const { toEmail, subject, htmlContent } = await req.json()

    if (!toEmail || !subject || !htmlContent) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields: toEmail, subject, htmlContent' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('📤 Sending email via SendGrid to:', toEmail)

    // Call SendGrid API
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{ email: toEmail }],
          subject: subject
        }],
        from: {
          email: SENDGRID_FROM_EMAIL,
          name: 'Sakura ERP'
        },
        content: [{
          type: 'text/html',
          value: htmlContent
        }]
      })
    })

    if (response.ok) {
      console.log('✅ Email sent successfully via SendGrid')
      return new Response(
        JSON.stringify({ success: true, message: 'Email sent successfully' }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    } else {
      const errorText = await response.text()
      console.error('❌ SendGrid API error:', response.status, errorText)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `SendGrid API error: ${response.status} - ${errorText}` 
        }),
        { 
          status: response.status, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }
  } catch (error) {
    console.error('❌ Error sending email:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Failed to send email' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

