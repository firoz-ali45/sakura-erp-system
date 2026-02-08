let i=null;const k=d=>new Promise(s=>{i&&document.body.removeChild(i);const{title:y="Confirm Action",message:g="Are you sure?",confirmText:h="OK",cancelText:b="Cancel",type:l="warning",icon:C="fas fa-exclamation-triangle"}=d,e=document.createElement("div");e.className="sakura-confirm-overlay",e.style.cssText=`
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
    `;const a=document.createElement("div");a.className="sakura-confirm-dialog",a.style.cssText=`
      background: white;
      border-radius: 16px;
      padding: 0;
      min-width: 400px;
      max-width: 500px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      animation: scaleIn 0.2s ease-out;
      font-family: 'Cairo', sans-serif;
      overflow: hidden;
    `;let o="#9333ea";l==="danger"?o="#dc2626":l==="warning"?o="#f59e0b":l==="info"?o="#3b82f6":l==="success"&&(o="#10b981");const r=document.createElement("div");r.style.cssText=`
      background: linear-gradient(135deg, ${o} 0%, ${o}dd 100%);
      color: white;
      padding: 20px 24px;
      display: flex;
      align-items: center;
      gap: 12px;
    `;const p=document.createElement("div");p.style.cssText=`
      font-size: 24px;
      width: 40px;
      height: 40px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(255, 255, 255, 0.2);
      border-radius: 50%;
    `,p.innerHTML=`<i class="${C}"></i>`;const m=document.createElement("div");m.style.cssText=`
      font-size: 18px;
      font-weight: 600;
      flex: 1;
    `,m.textContent=y,r.appendChild(p),r.appendChild(m);const f=document.createElement("div");f.style.cssText=`
      padding: 24px;
      color: #1f2937;
      font-size: 15px;
      line-height: 1.6;
    `,f.textContent=g;const c=document.createElement("div");c.style.cssText=`
      padding: 16px 24px;
      border-top: 1px solid #e5e7eb;
      display: flex;
      justify-content: flex-end;
      gap: 12px;
    `;const t=document.createElement("button");t.textContent=b,t.style.cssText=`
      padding: 10px 20px;
      border: 1px solid #d1d5db;
      border-radius: 8px;
      background: white;
      color: #374151;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
      font-family: 'Cairo', sans-serif;
    `,t.onmouseover=()=>{t.style.background="#f9fafb"},t.onmouseout=()=>{t.style.background="white"},t.onclick=()=>{document.body.removeChild(e),i=null,s(!1)};const n=document.createElement("button");n.textContent=h,n.style.cssText=`
      padding: 10px 20px;
      border: none;
      border-radius: 8px;
      background: ${o};
      color: white;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
      font-family: 'Cairo', sans-serif;
    `,n.onmouseover=()=>{n.style.opacity="0.9"},n.onmouseout=()=>{n.style.opacity="1"},n.onclick=()=>{document.body.removeChild(e),i=null,s(!0)},c.appendChild(t),c.appendChild(n),a.appendChild(r),a.appendChild(f),a.appendChild(c),e.appendChild(a),document.body.appendChild(e),i=e,e.onclick=u=>{u.target===e&&(document.body.removeChild(e),i=null,s(!1))};const x=u=>{u.key==="Escape"&&(document.body.removeChild(e),i=null,document.removeEventListener("keydown",x),s(!1))};document.addEventListener("keydown",x)});if(!document.getElementById("sakura-confirm-dialog-styles")){const d=document.createElement("style");d.id="sakura-confirm-dialog-styles",d.textContent=`
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
  `,document.head.appendChild(d)}export{k as showConfirmDialog};
