/**
 * Professional Centered Notification System for Sakura ERP
 * Provides centered, minimal branded notifications with slightly blue background
 */

// Sakura Brand Colors (Minimal Usage)
const SAKURA_COLORS = {
  primary: '#284b44',
  secondary: '#956c2a',
  accent: '#f0e1cd',
  success: '#10b981',
  error: '#ef4444',
  warning: '#f59e0b',
  info: '#3b82f6'
};

// Track notification queue for stacking
let notificationQueue = [];

/**
 * Show a centered, minimal branded notification
 * @param {string} message - The notification message
 * @param {string} type - Notification type: 'success', 'error', 'warning', 'info'
 * @param {number} duration - Duration in milliseconds (default: 3000)
 */
export function showNotification(message, type = 'success', duration = 3000) {
  // Create notification container if it doesn't exist
  let container = document.getElementById('sakura-notification-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'sakura-notification-container';
    container.style.cssText = `
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      z-index: 10000;
      display: flex;
      flex-direction: column;
      gap: 12px;
      pointer-events: none;
      max-width: 420px;
      width: 90%;
    `;
    document.body.appendChild(container);
  }

  // Create notification element
  const notification = document.createElement('div');
  notification.className = 'sakura-mini-notification';
  const notificationId = `notification-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  notification.id = notificationId;

  // Determine icon and color based on type (minimal Sakura branding)
  let icon = 'fa-check-circle';
  let bgColor = 'rgba(240, 248, 255, 0.98)'; // Slightly blue background
  let borderColor = SAKURA_COLORS.primary; // Minimal Sakura branding
  let iconColor = SAKURA_COLORS.success;
  let textColor = '#1f2937';

  switch (type) {
    case 'error':
      icon = 'fa-times-circle';
      iconColor = SAKURA_COLORS.error;
      break;
    case 'warning':
      icon = 'fa-exclamation-triangle';
      iconColor = SAKURA_COLORS.warning;
      break;
    case 'info':
      icon = 'fa-info-circle';
      iconColor = SAKURA_COLORS.info;
      break;
    case 'success':
    default:
      icon = 'fa-check-circle';
      iconColor = SAKURA_COLORS.success;
      break;
  }

  // Handle multi-line messages
  const messageLines = message.split('\n');
  const isMultiLine = messageLines.length > 1;

  // Set notification styles - Centered with slightly blue background and minimal Sakura branding
  notification.style.cssText = `
    background: ${bgColor};
    border: 1px solid ${borderColor};
    border-top: 3px solid ${borderColor};
    border-radius: 8px;
    box-shadow: 0 8px 24px rgba(40, 75, 68, 0.15), 0 4px 8px rgba(0, 0, 0, 0.1);
    padding: 16px 20px;
    display: flex;
    align-items: flex-start;
    gap: 14px;
    min-width: 320px;
    max-width: 420px;
    pointer-events: auto;
    animation: fadeInCenter 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    position: relative;
    overflow: hidden;
    backdrop-filter: blur(10px);
  `;

  // Create icon container
  const iconContainer = document.createElement('div');
  iconContainer.style.cssText = `
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 2px;
  `;

  const iconElement = document.createElement('i');
  iconElement.className = `fas ${icon}`;
  iconElement.style.cssText = `
    font-size: 18px;
    color: ${iconColor};
  `;
  iconContainer.appendChild(iconElement);

  // Create message container
  const messageContainer = document.createElement('div');
  messageContainer.style.cssText = `
    flex: 1;
    min-width: 0;
  `;

  const messageElement = document.createElement('div');
  messageElement.style.cssText = `
    color: ${textColor};
    font-size: 13px;
    font-weight: 500;
    line-height: 1.5;
    word-wrap: break-word;
  `;
  
  if (isMultiLine) {
    messageElement.innerHTML = messageLines.map(line => 
      line.trim() ? `<div style="margin-bottom: 4px;">${escapeHtml(line)}</div>` : ''
    ).join('');
  } else {
    messageElement.textContent = message;
  }
  
  messageContainer.appendChild(messageElement);

  // Create close button
  const closeButton = document.createElement('button');
  closeButton.innerHTML = '<i class="fas fa-times"></i>';
  closeButton.style.cssText = `
    background: transparent;
    border: none;
    color: #6b7280;
    width: 20px;
    height: 20px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: all 0.2s;
    padding: 0;
    font-size: 12px;
    margin-top: 2px;
  `;
  closeButton.onmouseover = () => {
    closeButton.style.background = '#f3f4f6';
    closeButton.style.color = '#374151';
  };
  closeButton.onmouseout = () => {
    closeButton.style.background = 'transparent';
    closeButton.style.color = '#6b7280';
  };
  closeButton.onclick = (e) => {
    e.stopPropagation();
    removeNotification(notificationId);
  };

  // Append elements
  notification.appendChild(iconContainer);
  notification.appendChild(messageContainer);
  notification.appendChild(closeButton);

  // Add to container
  container.appendChild(notification);
  notificationQueue.push(notificationId);

  // Add CSS animations if not already added
  if (!document.getElementById('sakura-mini-notification-styles')) {
    const style = document.createElement('style');
    style.id = 'sakura-mini-notification-styles';
    style.textContent = `
      @keyframes fadeInCenter {
        from {
          transform: scale(0.95);
          opacity: 0;
        }
        to {
          transform: scale(1);
          opacity: 1;
        }
      }
      @keyframes fadeOutCenter {
        from {
          transform: scale(1);
          opacity: 1;
        }
        to {
          transform: scale(0.95);
          opacity: 0;
        }
      }
      .sakura-mini-notification {
        transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.3s;
      }
    `;
    document.head.appendChild(style);
  }

  // Auto-remove after duration
  if (duration > 0) {
    setTimeout(() => {
      removeNotification(notificationId);
    }, duration);
  }

  return notification;
}

/**
 * Remove notification with animation
 */
function removeNotification(notificationId) {
  const notification = document.getElementById(notificationId);
  if (!notification) return;

  notification.style.animation = 'fadeOutCenter 0.3s cubic-bezier(0.16, 1, 0.3, 1)';
  setTimeout(() => {
    if (notification.parentNode) {
      notification.remove();
    }
    // Remove from queue
    notificationQueue = notificationQueue.filter(id => id !== notificationId);
    
    // Remove container if empty
    const container = document.getElementById('sakura-notification-container');
    if (container && container.children.length === 0) {
      container.remove();
    }
  }, 300);
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

