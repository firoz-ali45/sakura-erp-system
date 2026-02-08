// Professional Confirm Dialog Utility for Sakura ERP
// Replaces browser confirm() with branded modal

let confirmDialogInstance = null;

export const showConfirmDialog = (options) => {
  return new Promise((resolve) => {
    // Remove existing dialog if any
    if (confirmDialogInstance) {
      document.body.removeChild(confirmDialogInstance);
    }

    const {
      title = 'Confirm Action',
      message = 'Are you sure?',
      confirmText = 'OK',
      cancelText = 'Cancel',
      type = 'warning', // 'warning', 'danger', 'info', 'success'
      icon = 'fas fa-exclamation-triangle'
    } = options;

    // Create overlay with blur
    const overlay = document.createElement('div');
    overlay.className = 'sakura-confirm-overlay';
    overlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(4px);
      -webkit-backdrop-filter: blur(4px);
      z-index: 10000;
      display: flex;
      align-items: center;
      justify-content: center;
      animation: fadeIn 0.2s ease-out;
    `;

    // Create dialog
    const dialog = document.createElement('div');
    dialog.className = 'sakura-confirm-dialog';
    dialog.style.cssText = `
      background: white;
      border-radius: 16px;
      padding: 0;
      min-width: 400px;
      max-width: 500px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      animation: scaleIn 0.2s ease-out;
      font-family: 'Cairo', sans-serif;
      overflow: hidden;
    `;

    // Determine colors based on type
    let headerColor = '#9333ea'; // Default purple (Sakura brand)
    let iconColor = '#9333ea';
    
    if (type === 'danger') {
      headerColor = '#dc2626'; // Red
      iconColor = '#dc2626';
    } else if (type === 'warning') {
      headerColor = '#f59e0b'; // Amber
      iconColor = '#f59e0b';
    } else if (type === 'info') {
      headerColor = '#3b82f6'; // Blue
      iconColor = '#3b82f6';
    } else if (type === 'success') {
      headerColor = '#10b981'; // Green
      iconColor = '#10b981';
    }

    // Header
    const header = document.createElement('div');
    header.style.cssText = `
      background: linear-gradient(135deg, ${headerColor} 0%, ${headerColor}dd 100%);
      color: white;
      padding: 20px 24px;
      display: flex;
      align-items: center;
      gap: 12px;
    `;

    const iconEl = document.createElement('div');
    iconEl.style.cssText = `
      font-size: 24px;
      width: 40px;
      height: 40px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(255, 255, 255, 0.2);
      border-radius: 50%;
    `;
    iconEl.innerHTML = `<i class="${icon}"></i>`;

    const titleEl = document.createElement('div');
    titleEl.style.cssText = `
      font-size: 18px;
      font-weight: 600;
      flex: 1;
    `;
    titleEl.textContent = title;

    header.appendChild(iconEl);
    header.appendChild(titleEl);

    // Body
    const body = document.createElement('div');
    body.style.cssText = `
      padding: 24px;
      color: #1f2937;
      font-size: 15px;
      line-height: 1.6;
    `;
    body.textContent = message;

    // Footer
    const footer = document.createElement('div');
    footer.style.cssText = `
      padding: 16px 24px;
      border-top: 1px solid #e5e7eb;
      display: flex;
      justify-content: flex-end;
      gap: 12px;
    `;

    const cancelBtn = document.createElement('button');
    cancelBtn.textContent = cancelText;
    cancelBtn.style.cssText = `
      padding: 10px 20px;
      border: 1px solid #d1d5db;
      border-radius: 8px;
      background: white;
      color: #374151;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
      font-family: 'Cairo', sans-serif;
    `;
    cancelBtn.onmouseover = () => {
      cancelBtn.style.background = '#f9fafb';
    };
    cancelBtn.onmouseout = () => {
      cancelBtn.style.background = 'white';
    };
    cancelBtn.onclick = () => {
      document.body.removeChild(overlay);
      confirmDialogInstance = null;
      resolve(false);
    };

    const confirmBtn = document.createElement('button');
    confirmBtn.textContent = confirmText;
    confirmBtn.style.cssText = `
      padding: 10px 20px;
      border: none;
      border-radius: 8px;
      background: ${headerColor};
      color: white;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
      font-family: 'Cairo', sans-serif;
    `;
    confirmBtn.onmouseover = () => {
      confirmBtn.style.opacity = '0.9';
    };
    confirmBtn.onmouseout = () => {
      confirmBtn.style.opacity = '1';
    };
    confirmBtn.onclick = () => {
      document.body.removeChild(overlay);
      confirmDialogInstance = null;
      resolve(true);
    };

    footer.appendChild(cancelBtn);
    footer.appendChild(confirmBtn);

    // Assemble dialog
    dialog.appendChild(header);
    dialog.appendChild(body);
    dialog.appendChild(footer);

    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    confirmDialogInstance = overlay;

    // Close on overlay click
    overlay.onclick = (e) => {
      if (e.target === overlay) {
        document.body.removeChild(overlay);
        confirmDialogInstance = null;
        resolve(false);
      }
    };

    // Close on Escape key
    const handleEscape = (e) => {
      if (e.key === 'Escape') {
        document.body.removeChild(overlay);
        confirmDialogInstance = null;
        document.removeEventListener('keydown', handleEscape);
        resolve(false);
      }
    };
    document.addEventListener('keydown', handleEscape);
  });
};

// Add CSS animations
if (!document.getElementById('sakura-confirm-dialog-styles')) {
  const style = document.createElement('style');
  style.id = 'sakura-confirm-dialog-styles';
  style.textContent = `
    @keyframes fadeIn {
      from {
        opacity: 0;
      }
      to {
        opacity: 1;
      }
    }
    
    @keyframes scaleIn {
      from {
        transform: scale(0.9);
        opacity: 0;
      }
      to {
        transform: scale(1);
        opacity: 1;
      }
    }
  `;
  document.head.appendChild(style);
}

