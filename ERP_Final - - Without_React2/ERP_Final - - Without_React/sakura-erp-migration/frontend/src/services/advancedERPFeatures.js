// Advanced ERP Features - Same as index.html
// These classes use Supabase for audit logging, activity tracking, etc.

// ==================== AUDIT LOGGING ====================
export class AuditLogger {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
  }

  async logAction(action, entityType, entityId, oldValues = null, newValues = null) {
    if (!this.supabase) return;

    try {
      const currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
      const userId = currentUser.id ?? currentUser.email ?? currentUser.name ?? null;
      const { data, error } = await this.supabase
        .from('audit_logs')
        .insert([{
          user_id: userId ? String(userId) : null,
          action: action,
          entity_type: entityType,
          entity_id: entityId,
          old_values: oldValues,
          new_values: newValues,
          ip_address: await this.getIPAddress(),
          user_agent: navigator.userAgent
        }]);

      if (error) {
        console.error('Audit log error:', error);
      }
    } catch (error) {
      console.error('Audit logging failed:', error);
    }
  }

  async getIPAddress() {
    try {
      const response = await fetch('https://api.ipify.org?format=json');
      const data = await response.json();
      return data.ip;
    } catch {
      return 'unknown';
    }
  }
}

// ==================== ACTIVITY TRACKING ====================
export class ActivityTracker {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
  }

  async trackActivity(activityType, description, module = null, metadata = {}) {
    if (!this.supabase) return;

    try {
      const currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
      const { data, error } = await this.supabase
        .from('user_activities')
        .insert([{
          user_id: currentUser.id || null,
          activity_type: activityType,
          activity_description: description,
          module: module,
          metadata: metadata,
          ip_address: await this.getIPAddress(),
          user_agent: navigator.userAgent
        }]);

      if (error) {
        console.error('Activity tracking error:', error);
      }
    } catch (error) {
      console.error('Activity tracking failed:', error);
    }
  }

  async getIPAddress() {
    try {
      const response = await fetch('https://api.ipify.org?format=json');
      const data = await response.json();
      return data.ip;
    } catch {
      return 'unknown';
    }
  }
}

// ==================== SESSION MANAGEMENT ====================
export class SessionManager {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
    this.sessionTimeout = 30 * 60 * 1000; // 30 minutes
    this.checkInterval = null;
  }

  async createSession(userId) {
    if (!this.supabase) return null;

    try {
      const sessionToken = this.generateSessionToken();
      const expiresAt = new Date(Date.now() + this.sessionTimeout);

      const { data, error } = await this.supabase
        .from('user_sessions')
        .insert([{
          user_id: userId,
          session_token: sessionToken,
          ip_address: await this.getIPAddress(),
          user_agent: navigator.userAgent,
          expires_at: expiresAt.toISOString()
        }])
        .select()
        .single();

      if (error) {
        console.error('Session creation error:', error);
        return null;
      }

      localStorage.setItem('session_token', sessionToken);
      this.startSessionMonitoring();
      return data;
    } catch (error) {
      console.error('Session creation failed:', error);
      return null;
    }
  }

  async endSession(sessionToken) {
    if (!this.supabase) return;

    try {
      await this.supabase
        .from('user_sessions')
        .update({ is_active: false })
        .eq('session_token', sessionToken);

      localStorage.removeItem('session_token');
      this.stopSessionMonitoring();
    } catch (error) {
      console.error('Session end error:', error);
    }
  }

  startSessionMonitoring() {
    this.checkInterval = setInterval(() => {
      this.checkSession();
    }, 60000); // Check every minute
  }

  stopSessionMonitoring() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  async checkSession() {
    const sessionToken = localStorage.getItem('session_token');
    if (!sessionToken || !this.supabase) return;

    try {
      const { data, error } = await this.supabase
        .from('user_sessions')
        .select('*')
        .eq('session_token', sessionToken)
        .eq('is_active', true)
        .single();

      if (error || !data || new Date(data.expires_at) < new Date()) {
        // Session expired
        this.endSession(sessionToken);
        window.location.href = '/login';
      } else {
        // Update last activity
        await this.supabase
          .from('user_sessions')
          .update({ last_activity: new Date().toISOString() })
          .eq('session_token', sessionToken);
      }
    } catch (error) {
      console.error('Session check error:', error);
    }
  }

  generateSessionToken() {
    return 'sess_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  async getIPAddress() {
    try {
      const response = await fetch('https://api.ipify.org?format=json');
      const data = await response.json();
      return data.ip;
    } catch {
      return 'unknown';
    }
  }
}

// ==================== NOTIFICATION SYSTEM ====================
export class NotificationSystem {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
    this.notificationCheckInterval = null;
  }

  async createNotification(userId, title, message, type = 'info', actionUrl = null) {
    if (!this.supabase) return;

    try {
      const { data, error } = await this.supabase
        .from('notifications')
        .insert([{
          user_id: userId,
          title: title,
          message: message,
          type: type,
          action_url: actionUrl
        }])
        .select()
        .single();

      if (error) {
        console.error('Notification creation error:', error);
        return null;
      }

      // Show browser notification if permission granted
      this.showBrowserNotification(title, message);

      return data;
    } catch (error) {
      console.error('Notification creation failed:', error);
      return null;
    }
  }

  async getNotifications(userId, unreadOnly = false) {
    if (!this.supabase) return [];

    try {
      let query = this.supabase
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      const { data, error } = await query;

      if (error) {
        console.error('Get notifications error:', error);
        return [];
      }

      return data || [];
    } catch (error) {
      console.error('Get notifications failed:', error);
      return [];
    }
  }

  async markAsRead(notificationId) {
    if (!this.supabase) return;

    try {
      await this.supabase
        .from('notifications')
        .update({ 
          is_read: true,
          read_at: new Date().toISOString()
        })
        .eq('id', notificationId);
    } catch (error) {
      console.error('Mark as read error:', error);
    }
  }

  startNotificationPolling(userId) {
    this.notificationCheckInterval = setInterval(async () => {
      const notifications = await this.getNotifications(userId, true);
      this.updateNotificationBadge(notifications.length);
    }, 30000); // Check every 30 seconds
  }

  stopNotificationPolling() {
    if (this.notificationCheckInterval) {
      clearInterval(this.notificationCheckInterval);
      this.notificationCheckInterval = null;
    }
  }

  updateNotificationBadge(count) {
    const badge = document.getElementById('notification-badge');
    if (badge) {
      badge.textContent = count > 0 ? count : '';
      badge.style.display = count > 0 ? 'block' : 'none';
    }
  }

  async showBrowserNotification(title, message) {
    if (!('Notification' in window)) return;

    if (Notification.permission === 'granted') {
      new Notification(title, {
        body: message,
        icon: '/favicon.ico'
      });
    } else if (Notification.permission !== 'denied') {
      await Notification.requestPermission();
    }
  }
}

// ==================== ANALYTICS & REPORTING ====================
export class AnalyticsManager {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
  }

  async getUserStatistics(userId) {
    if (!this.supabase) return null;

    try {
      const { data, error } = await this.supabase
        .rpc('get_user_statistics', { p_user_id: userId });

      if (error) {
        console.error('Get user statistics error:', error);
        return null;
      }

      return data;
    } catch (error) {
      console.error('Get user statistics failed:', error);
      return null;
    }
  }

  async generateReport(reportName, reportType, parameters = {}) {
    if (!this.supabase) return null;

    try {
      const currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
      const { data, error } = await this.supabase
        .from('reports')
        .insert([{
          user_id: currentUser.id,
          report_name: reportName,
          report_type: reportType,
          parameters: parameters,
          status: 'pending'
        }])
        .select()
        .single();

      if (error) {
        console.error('Report generation error:', error);
        return null;
      }

      // Process report asynchronously
      this.processReport(data.id, reportType, parameters);

      return data;
    } catch (error) {
      console.error('Report generation failed:', error);
      return null;
    }
  }

  async processReport(reportId, reportType, parameters) {
    // This would typically be done server-side
    // For now, we'll just update the status
    if (!this.supabase) return;

    try {
      // Simulate report processing
      setTimeout(async () => {
        await this.supabase
          .from('reports')
          .update({
            status: 'completed',
            completed_at: new Date().toISOString(),
            file_url: `/reports/${reportId}.pdf` // Example
          })
          .eq('id', reportId);
      }, 5000);
    } catch (error) {
      console.error('Report processing error:', error);
    }
  }
}

// ==================== API KEY MANAGEMENT ====================
export class APIKeyManager {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
  }

  async createAPIKey(userId, keyName, permissions = {}) {
    if (!this.supabase) return null;

    try {
      const apiKey = this.generateAPIKey();
      const { data, error } = await this.supabase
        .from('api_keys')
        .insert([{
          user_id: userId,
          key_name: keyName,
          api_key: apiKey,
          permissions: permissions
        }])
        .select()
        .single();

      if (error) {
        console.error('API key creation error:', error);
        return null;
      }

      return data;
    } catch (error) {
      console.error('API key creation failed:', error);
      return null;
    }
  }

  async revokeAPIKey(apiKeyId) {
    if (!this.supabase) return;

    try {
      await this.supabase
        .from('api_keys')
        .update({ is_active: false })
        .eq('id', apiKeyId);
    } catch (error) {
      console.error('API key revocation error:', error);
    }
  }

  generateAPIKey() {
    return 'sk_' + Date.now() + '_' + Math.random().toString(36).substr(2, 32);
  }
}

// ==================== SYSTEM SETTINGS ====================
export class SystemSettings {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
    this.cache = {};
  }

  async getSetting(key, defaultValue = null) {
    if (this.cache[key]) {
      return this.cache[key];
    }

    if (!this.supabase) return defaultValue;

    try {
      const { data, error } = await this.supabase
        .from('system_settings')
        .select('setting_value')
        .eq('setting_key', key)
        .single();

      if (error || !data) {
        return defaultValue;
      }

      this.cache[key] = data.setting_value;
      return data.setting_value;
    } catch (error) {
      console.error('Get setting error:', error);
      return defaultValue;
    }
  }

  async setSetting(key, value, description = null) {
    if (!this.supabase) return;

    try {
      const currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
      const { data, error } = await this.supabase
        .from('system_settings')
        .upsert([{
          setting_key: key,
          setting_value: value,
          description: description,
          updated_by: currentUser.id
        }], {
          onConflict: 'setting_key'
        })
        .select()
        .single();

      if (error) {
        console.error('Set setting error:', error);
        return;
      }

      this.cache[key] = value;
      return data;
    } catch (error) {
      console.error('Set setting failed:', error);
    }
  }
}

