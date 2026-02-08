const r={primary:"#284b44",success:"#10b981",error:"#ef4444",warning:"#f59e0b",info:"#3b82f6"};let x=[];function v(a,t="success",s=3e3){let n=document.getElementById("sakura-notification-container");n||(n=document.createElement("div"),n.id="sakura-notification-container",n.style.cssText=`
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
    `,document.body.appendChild(n));const i=document.createElement("div");i.className="sakura-mini-notification";const d=`notification-${Date.now()}-${Math.random().toString(36).substr(2,9)}`;i.id=d;let c="fa-check-circle",h="rgba(240, 248, 255, 0.98)",y=r.primary,l=r.success,k="#1f2937";switch(t){case"error":c="fa-times-circle",l=r.error;break;case"warning":c="fa-exclamation-triangle",l=r.warning;break;case"info":c="fa-info-circle",l=r.info;break;case"success":default:c="fa-check-circle",l=r.success;break}const b=a.split(`
`),C=b.length>1;i.style.cssText=`
    background: ${h};
    border: 1px solid ${y};
    border-top: 3px solid ${y};
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
  `;const f=document.createElement("div");f.style.cssText=`
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 2px;
  `;const p=document.createElement("i");p.className=`fas ${c}`,p.style.cssText=`
    font-size: 18px;
    color: ${l};
  `,f.appendChild(p);const u=document.createElement("div");u.style.cssText=`
    flex: 1;
    min-width: 0;
  `;const m=document.createElement("div");m.style.cssText=`
    color: ${k};
    font-size: 13px;
    font-weight: 500;
    line-height: 1.5;
    word-wrap: break-word;
  `,C?m.innerHTML=b.map(o=>o.trim()?`<div style="margin-bottom: 4px;">${w(o)}</div>`:"").join(""):m.textContent=a,u.appendChild(m);const e=document.createElement("button");if(e.innerHTML='<i class="fas fa-times"></i>',e.style.cssText=`
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
  `,e.onmouseover=()=>{e.style.background="#f3f4f6",e.style.color="#374151"},e.onmouseout=()=>{e.style.background="transparent",e.style.color="#6b7280"},e.onclick=o=>{o.stopPropagation(),g(d)},i.appendChild(f),i.appendChild(u),i.appendChild(e),n.appendChild(i),x.push(d),!document.getElementById("sakura-mini-notification-styles")){const o=document.createElement("style");o.id="sakura-mini-notification-styles",o.textContent=`
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
    `,document.head.appendChild(o)}return s>0&&setTimeout(()=>{g(d)},s),i}function g(a){const t=document.getElementById(a);t&&(t.style.animation="fadeOutCenter 0.3s cubic-bezier(0.16, 1, 0.3, 1)",setTimeout(()=>{t.parentNode&&t.remove(),x=x.filter(n=>n!==a);const s=document.getElementById("sakura-notification-container");s&&s.children.length===0&&s.remove()},300))}function w(a){const t=document.createElement("div");return t.textContent=a,t.innerHTML}export{v as s};
