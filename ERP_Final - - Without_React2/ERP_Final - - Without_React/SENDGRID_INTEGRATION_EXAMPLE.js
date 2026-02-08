// ============================================
// SENDGRID EMAIL INTEGRATION EXAMPLE
// ============================================
// Ye code `index.html` me `sendProfessionalEmail()` function me add karna hai

// Step 1: SendGrid API Key ko secure jagah rakho
// (Production me environment variable use karo)
const SENDGRID_API_KEY = 'YOUR_SENDGRID_API_KEY_HERE'; // Replace with your actual API key

// Step 2: SendGrid API function
async function sendEmailViaSendGrid(toEmail, subject, htmlContent) {
    const SENDGRID_URL = 'https://api.sendgrid.com/v3/mail/send';
    
    const emailData = {
        personalizations: [{
            to: [{ email: toEmail }],
            subject: subject
        }],
        from: { 
            email: 'noreply@sakuraerp.com', // Your verified sender email
            name: 'Sakura ERP Team' 
        },
        content: [{
            type: 'text/html',
            value: htmlContent
        }]
    };
    
    try {
        const response = await fetch(SENDGRID_URL, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${SENDGRID_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(emailData)
        });
        
        if (response.ok) {
            console.log('✅ Email sent successfully via SendGrid to:', toEmail);
            return { success: true };
        } else {
            const errorText = await response.text();
            console.error('❌ SendGrid API Error:', errorText);
            return { success: false, error: errorText };
        }
    } catch (error) {
        console.error('❌ SendGrid Network Error:', error);
        return { success: false, error: error.message };
    }
}

// Step 3: Update sendProfessionalEmail function
// Existing function me ye code add karo (end me, return se pehle):

/*
// In production, send actual email using SendGrid
if (SENDGRID_API_KEY && SENDGRID_API_KEY !== 'YOUR_SENDGRID_API_KEY_HERE') {
    const emailResult = await sendEmailViaSendGrid(userEmail, subject, emailBody);
    if (emailResult.success) {
        console.log('✅ Professional email sent via SendGrid');
    } else {
        console.warn('⚠️ SendGrid email failed, but continuing...', emailResult.error);
        // Fallback: Still show notification and log to console
    }
}
*/

// ============================================
// SECURITY NOTE:
// ============================================
// API Key ko directly code me mat rakho!
// Better approach:
// 1. Supabase Edge Function me rakho
// 2. Ya environment variable use karo
// 3. Ya Supabase Secrets use karo

// ============================================
// SUPABASE EDGE FUNCTION APPROACH (Recommended):
// ============================================
// Create a Supabase Edge Function for sending emails
// This keeps your API key secure on the server

/*
// supabase/functions/send-email/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { to, subject, html } = await req.json()
  
  const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("SENDGRID_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to }] }],
      from: { email: "noreply@sakuraerp.com", name: "Sakura ERP" },
      subject: subject,
      content: [{ type: "text/html", value: html }],
    }),
  })
  
  return new Response(JSON.stringify({ success: response.ok }), {
    headers: { "Content-Type": "application/json" },
  })
})
*/

// Then call from frontend:
/*
const emailResult = await supabaseClient.functions.invoke('send-email', {
    body: { to: userEmail, subject: subject, html: emailBody }
});
*/

