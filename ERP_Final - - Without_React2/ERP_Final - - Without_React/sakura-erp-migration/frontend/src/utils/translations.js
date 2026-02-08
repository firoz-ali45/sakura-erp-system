// Translation utility for Arabic/English support
// Gets current language from localStorage or window

const translations = {
  en: {
    // Purchase Order
    'Purchase Order': 'Purchase Order',
    'Purchase Order – Sakura ERP': 'Purchase Order – Sakura ERP',
    'Supplier': 'Supplier',
    'Destination': 'Destination',
    'Business Date': 'Business Date',
    'Creator': 'Creator',
    'Submitter': 'Submitter',
    'Approver': 'Approver',
    'Created At': 'Created At',
    'Notes': 'Notes',
    'Delivery Date': 'Delivery Date',
    'Purchase Order Total Cost': 'Purchase Order Total Cost',
    'Number of Items': 'Number of Items',
    'Items': 'Items',
    'Name': 'Name',
    'SKU': 'SKU',
    'Available Quantity': 'Available Quantity',
    'Cost Per Unit': 'Cost Per Unit',
    'Ordered Quantity': 'Ordered Quantity',
    'Received Quantity': 'Received Quantity',
    'Remaining Quantity': 'Remaining Quantity',
    'Total Cost': 'Total Cost',
    'No items': 'No items',
    'Sakura ERP Management System': 'Sakura ERP Management System',
    'Page': 'Page',
    
    // GRN
    'GRN': 'GRN',
    'GRN – Sakura ERP': 'GRN – Sakura ERP',
    'GRN Date': 'GRN Date',
    'Purchase Order Reference': 'Purchase Order Reference',
    'Receiving Location': 'Receiving Location',
    'Received By': 'Received By',
    'Supplier Invoice Number': 'Supplier Invoice Number',
    'Delivery Note Number': 'Delivery Note Number',
    'QC Checked By': 'QC Checked By',
    'GRN Approved By': 'GRN Approved By',
    'External Reference ID': 'External Reference ID',
    'Number of Batches': 'Number of Batches',
    'Unit': 'Unit',
    'Packaging Type': 'Packaging Type',
    'Inspection': 'Inspection',
    'Batches (ISO 22000 Compliant)': 'Batches (ISO 22000 Compliant)',
    'Batch ID': 'Batch ID',
    'Item': 'Item',
    'Expiry Date': 'Expiry Date',
    'Batch Quantity': 'Batch Quantity',
    'Storage Location': 'Storage Location',
    'Vendor Batch Number': 'Vendor Batch Number',
    'QC Status': 'QC Status',
    'Created By': 'Created By',
    'Created Date': 'Created Date',
    'QC & Inspection Details (ISO 22000)': 'QC & Inspection Details (ISO 22000)',
    
    // Transfer Order
    'Transfer Order': 'Transfer Order',
    'Transfer Order – Sakura ERP': 'Transfer Order – Sakura ERP',
    'From Location': 'From Location',
    'To Location': 'To Location',
    'Transfer Date': 'Transfer Date',
    'Requested By': 'Requested By',
    'Approved By': 'Approved By',
    'Status': 'Status',
    'Draft': 'Draft',
    'Pending': 'Pending',
    'Approved': 'Approved',
    'Rejected': 'Rejected',
    'Under Inspection': 'Under Inspection',
    'Closed': 'Closed',
    'Partially Received': 'Partially Received',
    'Fully Received': 'Fully Received',
    'Not Received Yet': 'Not Received Yet',
    'Quantity': 'Quantity',
    
    // Common UI Elements
    'All': 'All',
    'Previous': 'Previous',
    'Next': 'Next',
    'Filter': 'Filter',
    'Clear Filter': 'Clear Filter',
    'Close': 'Close',
    'Save': 'Save',
    'Cancel': 'Cancel',
    'Delete': 'Delete',
    'Edit': 'Edit',
    'View': 'View',
    'Actions': 'Actions',
    'Export': 'Export',
    'Export All': 'Export All',
    'Export Selected': 'Export Selected',
    'Import': 'Import',
    'Import / Export': 'Import / Export',
    'Download Template': 'Download Template',
    'Selected': 'Selected',
    'Clear Selection': 'Clear Selection',
    
    // Inventory Items
    'Inventory Items': 'Inventory Items',
    'Create Item': 'Create Item',
    'Create item': 'Create item',
    'Import Items': 'Import Items',
    'Export Items': 'Export Items',
    'Category': 'Category',
    'Deleted': 'Deleted',
    'Name Localized': 'Name Localized',
    'Storage Unit': 'Storage Unit',
    'Storage To Ingredient': 'Storage To Ingredient',
    'Barcode': 'Barcode',
    'Minimum Level': 'Minimum Level',
    'Maximum Level': 'Maximum Level',
    'Ingredient Unit': 'Ingredient Unit',
    'Costing Method': 'Costing Method',
    'Cost': 'Cost',
    'Par Level': 'Par Level',
    'Factor': 'Factor',
    'Production Section': 'Production Section',
    'Advanced Options': 'Advanced Options',
    'Hide': 'Hide',
    'Choose...': 'Choose...',
    'From Transactions': 'From Transactions',
    'Standard Cost': 'Standard Cost',
    'Average Cost': 'Average Cost',
    'Section A': 'Section A',
    'Section B': 'Section B',
    'Search by name...': 'Search by name...',
    'Search by SKU...': 'Search by SKU...',
    'Including': 'Including',
    'Excluding': 'Excluding',
    'Auto-generated': 'Auto-generated',
    
    // Purchase Orders
    'Purchase Orders': 'Purchase Orders',
    'New Purchase Order': 'New Purchase Order',
    'GRN Receiving Details': 'GRN Receiving Details',
    'GRN Reference': 'GRN Reference',
    'View GRN Details': 'View GRN Details',
    'No GRN found for this item': 'No GRN found for this item',
    'Create GRN': 'Create GRN',
    
    // Suppliers
    'Suppliers': 'Suppliers',
    'Add Supplier': 'Add Supplier',
    'Contact': 'Contact',
    'Code': 'Code',
    
    // Transfer Orders
    'Transfer Orders': 'Transfer Orders',
    'New Transfer Order': 'New Transfer Order',
    'Declined': 'Declined',
    'Accepted': 'Accepted',
    'Warehouse': 'Warehouse',
    'CREATED': 'CREATED',
    'BUSINESS DATE': 'BUSINESS DATE',
    'DESTINATION': 'DESTINATION',
    
    // GRN
    'GRN & Batch Control': 'GRN & Batch Control',
    'New GRN': 'New GRN',
    'Review & Finalize': 'Review & Finalize',
    'RECEIVED BY': 'RECEIVED BY',
    'RECEIVING LOCATION': 'RECEIVING LOCATION',
    'SUPPLIER': 'SUPPLIER',
    'PURCHASE ORDER': 'PURCHASE ORDER',
    'GRN DATE': 'GRN DATE',
    'GRN NUMBER': 'GRN NUMBER',
    
    // Home Portal / ERP Command Center
    'ERP Command Center': 'ERP Command Center',
    'Integrated analytics for strategic decision-making.': 'Integrated analytics for strategic decision-making.',
    'Working Capital Health': 'Working Capital Health',
    'An overall score based on overdue debt, forecast accuracy, and capital efficiency.': 'An overall score based on overdue debt, forecast accuracy, and capital efficiency.',
    'Payables Aging Analysis': 'Payables Aging Analysis',
    'Current': 'Current',
    'Overdue': 'Overdue',
    'Recommendation Engine': 'Recommendation Engine',
    'Operational Intelligence': 'Operational Intelligence',
    'AI-powered operational efficiency score across all business units.': 'AI-powered operational efficiency score across all business units.',
    'Risk Exposure Index': 'Risk Exposure Index',
    'Comprehensive risk assessment across financial, operational, and supply chain.': 'Comprehensive risk assessment across financial, operational, and supply chain.',
    'Process Optimization': 'Process Optimization',
    'Automated process improvement recommendations for maximum efficiency.': 'Automated process improvement recommendations for maximum efficiency.',
    'Growth Potential Score': 'Growth Potential Score',
    'Strategic growth opportunities based on current performance and market conditions.': 'Strategic growth opportunities based on current performance and market conditions.',
    'Non-Productive Capital': 'Non-Productive Capital',
    'Total cash tied up in overdue payments and overstocked items.': 'Total cash tied up in overdue payments and overstocked items.',
    'Total Near-Term Cash Outflow': 'Total Near-Term Cash Outflow',
    'Combines current dues with the forecasted purchase budget.': 'Combines current dues with the forecasted purchase budget.',
    'Cost Efficiency Ratio': 'Cost Efficiency Ratio',
    'Revenue Optimization': 'Revenue Optimization',
    'Financial Stability Score': 'Financial Stability Score',
    'Profitability Index': 'Profitability Index',
    '/ 100': '/ 100',
    
    // Filter Modal Labels
    'Advanced Filter': 'Advanced Filter',
    'Business Date': 'Business Date',
    'Business Date From': 'Business Date From',
    'Business Date To': 'Business Date To',
    'Reference': 'Reference',
    'Receiving Status': 'Receiving Status',
    'Submitter': 'Submitter',
    'Creator': 'Creator',
    'Approver': 'Approver',
    'Delivery Date': 'Delivery Date',
    'Delivery Date From': 'Delivery Date From',
    'Delivery Date To': 'Delivery Date To',
    'Updated After': 'Updated After',
    'Purchase Order': 'Purchase Order',
    'GRN Number': 'GRN Number',
    'Receiving Location': 'Receiving Location',
    'GRN Date From': 'GRN Date From',
    'GRN Date To': 'GRN Date To',
    'Created After': 'Created After',
    'Any': 'Any',
    'Apply': 'Apply',
    'Clear': 'Clear',
    'Search by PO number': 'Search by PO number',
    'Search by GRN number': 'Search by GRN number',
    'dd-mm-yyyy': 'dd-mm-yyyy',
    'Choose...': 'Choose...',
    
    // Table Headers
    'ACTIONS': 'ACTIONS',
    'RECEIVED BY': 'RECEIVED BY',
    'RECEIVING LOCATION': 'RECEIVING LOCATION',
    'SUPPLIER': 'SUPPLIER',
    'PURCHASE ORDER': 'PURCHASE ORDER',
    'GRN DATE': 'GRN DATE',
    'GRN NUMBER': 'GRN NUMBER',
    'Reference': 'Reference',
    'Business Date': 'Business Date',
    'Total Amount': 'Total Amount',
    'Receiving': 'Receiving',
    'CREATED': 'CREATED',
    'BUSINESS DATE': 'BUSINESS DATE',
    'DESTINATION': 'DESTINATION',
    'WAREHOUSE': 'WAREHOUSE',
    'STATUS': 'STATUS',
  },
  ar: {
    // Purchase Order
    'Purchase Order': 'أمر الشراء',
    'Purchase Order – Sakura ERP': 'أمر الشراء – ساكورا ERP',
    'Supplier': 'المورد',
    'Destination': 'الوجهة',
    'Business Date': 'تاريخ العمل',
    'Creator': 'المنشئ',
    'Submitter': 'المقدم',
    'Approver': 'الموافق',
    'Created At': 'تاريخ الإنشاء',
    'Notes': 'ملاحظات',
    'Delivery Date': 'تاريخ التسليم',
    'Purchase Order Total Cost': 'إجمالي تكلفة أمر الشراء',
    'Number of Items': 'عدد العناصر',
    'Items': 'العناصر',
    'Name': 'الاسم',
    'SKU': 'رمز SKU',
    'Available Quantity': 'الكمية المتاحة',
    'Cost Per Unit': 'التكلفة لكل وحدة',
    'Ordered Quantity': 'الكمية المطلوبة',
    'Received Quantity': 'الكمية المستلمة',
    'Remaining Quantity': 'الكمية المتبقية',
    'Total Cost': 'التكلفة الإجمالية',
    'No items': 'لا توجد عناصر',
    'Sakura ERP Management System': 'نظام إدارة ساكورا ERP',
    'Page': 'صفحة',
    
    // GRN
    'GRN': 'إذن استلام البضائع',
    'GRN – Sakura ERP': 'إذن استلام البضائع – ساكورا ERP',
    'GRN Date': 'تاريخ إذن الاستلام',
    'Purchase Order Reference': 'مرجع أمر الشراء',
    'Receiving Location': 'موقع الاستلام',
    'Received By': 'استلم بواسطة',
    'Supplier Invoice Number': 'رقم فاتورة المورد',
    'Delivery Note Number': 'رقم إيصال التسليم',
    'QC Checked By': 'فحص بواسطة',
    'GRN Approved By': 'تمت الموافقة على إذن الاستلام بواسطة',
    'External Reference ID': 'معرف المرجع الخارجي',
    'Number of Batches': 'عدد الدفعات',
    'Unit': 'الوحدة',
    'Packaging Type': 'نوع التعبئة',
    'Inspection': 'التفتيش',
    'Batches (ISO 22000 Compliant)': 'الدفعات (متوافقة مع ISO 22000)',
    'Batch ID': 'معرف الدفعة',
    'Item': 'العنصر',
    'Expiry Date': 'تاريخ انتهاء الصلاحية',
    'Batch Quantity': 'كمية الدفعة',
    'Storage Location': 'موقع التخزين',
    'Vendor Batch Number': 'رقم دفعة المورد',
    'QC Status': 'حالة مراقبة الجودة',
    'Created By': 'تم الإنشاء بواسطة',
    'Created Date': 'تاريخ الإنشاء',
    'QC & Inspection Details (ISO 22000)': 'تفاصيل مراقبة الجودة والتفتيش (ISO 22000)',
    
    // Transfer Order
    'Transfer Order': 'أمر النقل',
    'Transfer Order – Sakura ERP': 'أمر النقل – ساكورا ERP',
    'From Location': 'من الموقع',
    'To Location': 'إلى الموقع',
    'Transfer Date': 'تاريخ النقل',
    'Requested By': 'طلب بواسطة',
    'Approved By': 'تمت الموافقة بواسطة',
    'Status': 'الحالة',
    'Draft': 'مسودة',
    'Pending': 'قيد الانتظار',
    'Approved': 'موافق عليه',
    'Rejected': 'مرفوض',
    'Under Inspection': 'قيد التفتيش',
    'Closed': 'مغلق',
    'Partially Received': 'مستلم جزئياً',
    'Fully Received': 'مستلم بالكامل',
    'Not Received Yet': 'لم يتم الاستلام بعد',
    'Quantity': 'الكمية',
    
    // Common UI Elements
    'All': 'الكل',
    'Previous': 'السابق',
    'Next': 'التالي',
    'Filter': 'تصفية',
    'Clear Filter': 'مسح التصفية',
    'Close': 'إغلاق',
    'Save': 'حفظ',
    'Cancel': 'إلغاء',
    'Delete': 'حذف',
    'Edit': 'تعديل',
    'View': 'عرض',
    'Actions': 'الإجراءات',
    'Export': 'تصدير',
    'Export All': 'تصدير الكل',
    'Export Selected': 'تصدير المحدد',
    'Import': 'استيراد',
    'Import / Export': 'استيراد / تصدير',
    'Download Template': 'تحميل القالب',
    'Selected': 'محدد',
    'Clear Selection': 'مسح التحديد',
    
    // Inventory Items
    'Inventory Items': 'عناصر المخزون',
    'Create Item': 'إنشاء عنصر',
    'Create item': 'إنشاء عنصر',
    'Import Items': 'استيراد العناصر',
    'Export Items': 'تصدير العناصر',
    'Category': 'الفئة',
    'Deleted': 'محذوف',
    'Name Localized': 'الاسم المحلي',
    'Storage Unit': 'وحدة التخزين',
    'Storage To Ingredient': 'التخزين إلى المكون',
    'Barcode': 'الرمز الشريطي',
    'Minimum Level': 'الحد الأدنى',
    'Maximum Level': 'الحد الأقصى',
    'Ingredient Unit': 'وحدة المكون',
    'Costing Method': 'طريقة التكلفة',
    'Cost': 'التكلفة',
    'Par Level': 'مستوى بار',
    'Factor': 'العامل',
    'Production Section': 'قسم الإنتاج',
    'Advanced Options': 'خيارات متقدمة',
    'Hide': 'إخفاء',
    'Choose...': 'اختر...',
    'From Transactions': 'من المعاملات',
    'Standard Cost': 'التكلفة القياسية',
    'Average Cost': 'متوسط التكلفة',
    'Section A': 'القسم أ',
    'Section B': 'القسم ب',
    'Search by name...': 'البحث بالاسم...',
    'Search by SKU...': 'البحث برمز SKU...',
    'Including': 'بما في ذلك',
    'Excluding': 'باستثناء',
    'Auto-generated': 'تم إنشاؤه تلقائياً',
    
    // Purchase Orders
    'Purchase Orders': 'أوامر الشراء',
    'New Purchase Order': 'أمر شراء جديد',
    'GRN Receiving Details': 'تفاصيل استلام إذن الاستلام',
    'GRN Reference': 'مرجع إذن الاستلام',
    'View GRN Details': 'عرض تفاصيل إذن الاستلام',
    'No GRN found for this item': 'لم يتم العثور على إذن استلام لهذا العنصر',
    'Create GRN': 'إنشاء إذن استلام',
    
    // Suppliers
    'Suppliers': 'الموردون',
    'Add Supplier': 'إضافة مورد',
    'Contact': 'جهة الاتصال',
    'Code': 'الرمز',
    
    // Transfer Orders
    'Transfer Orders': 'أوامر النقل',
    'New Transfer Order': 'أمر نقل جديد',
    'Declined': 'مرفوض',
    'Accepted': 'مقبول',
    'Warehouse': 'المستودع',
    'CREATED': 'تاريخ الإنشاء',
    'BUSINESS DATE': 'تاريخ العمل',
    'DESTINATION': 'الوجهة',
    
    // GRN
    'GRN & Batch Control': 'التحكم في إذن الاستلام والدفعات',
    'New GRN': 'إذن استلام جديد',
    'Review & Finalize': 'مراجعة وإنهاء',
    'RECEIVED BY': 'استلم بواسطة',
    'RECEIVING LOCATION': 'موقع الاستلام',
    'SUPPLIER': 'المورد',
    'PURCHASE ORDER': 'أمر الشراء',
    'GRN DATE': 'تاريخ إذن الاستلام',
    'GRN NUMBER': 'رقم إذن الاستلام',
    
    // Home Portal / ERP Command Center
    'ERP Command Center': 'مركز قيادة ERP',
    'Integrated analytics for strategic decision-making.': 'تحليلات متكاملة لاتخاذ قرارات استراتيجية.',
    'Working Capital Health': 'صحة رأس المال العامل',
    'An overall score based on overdue debt, forecast accuracy, and capital efficiency.': 'نقاط إجمالية تعتمد على الديون المتأخرة ودقة التوقعات وكفاءة رأس المال.',
    'Payables Aging Analysis': 'تحليل شيخوخة الدائنين',
    'Current': 'الحالي',
    'Overdue': 'متأخر',
    'Recommendation Engine': 'محرك التوصيات',
    'Operational Intelligence': 'الذكاء التشغيلي',
    'AI-powered operational efficiency score across all business units.': 'نقاط كفاءة تشغيلية مدعومة بالذكاء الاصطناعي عبر جميع وحدات الأعمال.',
    'Risk Exposure Index': 'مؤشر التعرض للمخاطر',
    'Comprehensive risk assessment across financial, operational, and supply chain.': 'تقييم شامل للمخاطر عبر المالية والتشغيل وسلسلة التوريد.',
    'Process Optimization': 'تحسين العمليات',
    'Automated process improvement recommendations for maximum efficiency.': 'توصيات تحسين العمليات الآلية لأقصى كفاءة.',
    'Growth Potential Score': 'نقاط إمكانات النمو',
    'Strategic growth opportunities based on current performance and market conditions.': 'فرص النمو الاستراتيجية بناءً على الأداء الحالي وظروف السوق.',
    'Non-Productive Capital': 'رأس المال غير المنتج',
    'Total cash tied up in overdue payments and overstocked items.': 'إجمالي النقد المقيد في المدفوعات المتأخرة والعناصر المخزونة بشكل مفرط.',
    'Total Near-Term Cash Outflow': 'إجمالي التدفقات النقدية الخارجة قصيرة الأجل',
    'Combines current dues with the forecasted purchase budget.': 'يجمع المستحقات الحالية مع ميزانية الشراء المتوقعة.',
    'Cost Efficiency Ratio': 'نسبة كفاءة التكلفة',
    'Revenue Optimization': 'تحسين الإيرادات',
    'Financial Stability Score': 'نقاط الاستقرار المالي',
    'Profitability Index': 'مؤشر الربحية',
    '/ 100': '/ 100',
    
    // Filter Modal Labels
    'Advanced Filter': 'تصفية متقدمة',
    'Business Date': 'تاريخ العمل',
    'Business Date From': 'تاريخ العمل من',
    'Business Date To': 'تاريخ العمل إلى',
    'Reference': 'المرجع',
    'Receiving Status': 'حالة الاستلام',
    'Submitter': 'المقدم',
    'Creator': 'المنشئ',
    'Approver': 'الموافق',
    'Delivery Date': 'تاريخ التسليم',
    'Delivery Date From': 'تاريخ التسليم من',
    'Delivery Date To': 'تاريخ التسليم إلى',
    'Updated After': 'تم التحديث بعد',
    'Purchase Order': 'أمر الشراء',
    'GRN Number': 'رقم إذن الاستلام',
    'Receiving Location': 'موقع الاستلام',
    'GRN Date From': 'تاريخ إذن الاستلام من',
    'GRN Date To': 'تاريخ إذن الاستلام إلى',
    'Created After': 'تم الإنشاء بعد',
    'Any': 'أي',
    'Apply': 'تطبيق',
    'Clear': 'مسح',
    'Search by PO number': 'البحث برقم أمر الشراء',
    'Search by GRN number': 'البحث برقم إذن الاستلام',
    'dd-mm-yyyy': 'يوم-شهر-سنة',
    'Choose...': 'اختر...',
    
    // Table Headers
    'ACTIONS': 'الإجراءات',
    'RECEIVED BY': 'استلم بواسطة',
    'RECEIVING LOCATION': 'موقع الاستلام',
    'SUPPLIER': 'المورد',
    'PURCHASE ORDER': 'أمر الشراء',
    'GRN DATE': 'تاريخ إذن الاستلام',
    'GRN NUMBER': 'رقم إذن الاستلام',
    'Reference': 'المرجع',
    'Business Date': 'تاريخ العمل',
    'Total Amount': 'المبلغ الإجمالي',
    'Receiving': 'الاستلام',
    'CREATED': 'تاريخ الإنشاء',
    'BUSINESS DATE': 'تاريخ العمل',
    'DESTINATION': 'الوجهة',
    'WAREHOUSE': 'المستودع',
    'STATUS': 'الحالة',
  }
};

// Get current language
export const getCurrentLanguage = () => {
  if (typeof window !== 'undefined') {
    // Try multiple sources to get the current language
    const lang = window.currentLang || 
                 (typeof localStorage !== 'undefined' ? localStorage.getItem('portalLang') : null) ||
                 (window.parent && window.parent.currentLang) ||
                 (window.parent && typeof window.parent.localStorage !== 'undefined' ? window.parent.localStorage.getItem('portalLang') : null) ||
                 'en';
    
    // Debug log to help troubleshoot
    if (typeof console !== 'undefined' && console.log) {
      console.log('🌐 getCurrentLanguage() detected:', lang, {
        'window.currentLang': window.currentLang,
        'localStorage.portalLang': typeof localStorage !== 'undefined' ? localStorage.getItem('portalLang') : 'N/A',
        'parent.currentLang': window.parent ? window.parent.currentLang : 'N/A'
      });
    }
    
    return lang;
  }
  return 'en';
};

// Translate function
export const t = (key, lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  const langTranslations = translations[currentLang] || translations.en;
  return langTranslations[key] || key;
};

// Format date based on language
export const formatDateByLang = (date, lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  if (!date) return '—';
  const d = new Date(date);
  
  if (currentLang === 'ar') {
    return d.toLocaleDateString('ar-SA', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit' 
    });
  }
  return d.toLocaleDateString('en-GB', { 
    year: 'numeric', 
    month: '2-digit', 
    day: '2-digit' 
  });
};

// Format date time based on language
export const formatDateTimeByLang = (date, lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  if (!date) return 'N/A';
  const d = new Date(date);
  
  if (currentLang === 'ar') {
    return d.toLocaleDateString('ar-SA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });
  }
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
};

// Format print date/time based on language
export const formatPrintDateTime = (lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  const now = new Date();
  
  if (currentLang === 'ar') {
    const printDate = now.toLocaleDateString('ar-SA', { 
      year: 'numeric', 
      month: '2-digit', 
      day: '2-digit' 
    });
    const printTime = now.toLocaleTimeString('ar-SA', { 
      hour: '2-digit', 
      minute: '2-digit', 
      hour12: true 
    });
    return { printDate, printTime };
  }
  
  const printDate = now.toLocaleDateString('en-US', { 
    year: 'numeric', 
    month: '2-digit', 
    day: '2-digit' 
  });
  const printTime = now.toLocaleTimeString('en-US', { 
    hour: '2-digit', 
    minute: '2-digit', 
    hour12: true 
  });
  return { printDate, printTime };
};

// Get direction based on language
export const getDirection = (lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  return currentLang === 'ar' ? 'rtl' : 'ltr';
};

// Get text alignment based on language
export const getTextAlign = (lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  return currentLang === 'ar' ? 'right' : 'left';
};

// Get status translation
export const translateStatus = (status, lang = null) => {
  const currentLang = lang || getCurrentLanguage();
  const statusKey = status.charAt(0).toUpperCase() + status.slice(1).replace('_', ' ');
  return t(statusKey, currentLang) || statusKey;
};

export default {
  t,
  getCurrentLanguage,
  formatDateByLang,
  formatDateTimeByLang,
  formatPrintDateTime,
  getDirection,
  getTextAlign,
  translateStatus
};

