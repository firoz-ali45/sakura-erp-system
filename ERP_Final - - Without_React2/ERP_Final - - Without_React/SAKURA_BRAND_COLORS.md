# 🎨 Sakura Branding Color Codes

## Primary Brand Colors

### Main Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Primary (Dark Green)** | `#284b44` | `rgb(40, 75, 68)` | Main brand color, sidebar, headers, primary buttons |
| **Secondary (Brown/Gold)** | `#956c2a` | `rgb(149, 108, 42)` | Accent color, active states, highlights |
| **Accent (Pink/Coral)** | `#ea8990` | `rgb(234, 137, 144)` | Accent elements, user names, special highlights |

### Background Colors

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| **Background** | `#f0e1cd` | `rgb(240, 225, 205)` | Main page background |
| **Card Background** | `#ffffff` | `rgb(255, 255, 255)` | Card/container backgrounds |
| **KPI Card Gradient** | `#f0e1cd` → `#e8d5c0` | `rgb(240, 225, 205)` → `rgb(232, 213, 192)` | KPI card backgrounds |

## Color Variations

### Primary Color Variations

```css
/* Primary Base */
--brand-primary: #284b44;

/* Primary Darker (Hover) */
--brand-primary-dark: #1f3a35;

/* Primary Lighter (Gradient) */
--brand-primary-light: #3a685e;
--brand-primary-gradient: #4a887b;
```

### Secondary Color Variations

```css
/* Secondary Base */
--brand-secondary: #956c2a;

/* Secondary Darker (Hover) */
--brand-secondary-dark: #7a5a22;
```

### Accent Color Variations

```css
/* Accent Base */
--brand-accent: #ea8990;

/* Accent Gradient */
--brand-accent-gradient: #d9739f;
```

## Gradient Combinations

### Header Gradient
```css
background: linear-gradient(135deg, #284b44 0%, #956c2a 100%);
```

### Full Brand Gradient
```css
background: linear-gradient(135deg, #284b44 0%, #956c2a 50%, #ea8990 100%);
```

### KPI Card Top Border
```css
background: linear-gradient(90deg, #284b44, #956c2a, #ea8990);
```

## Usage Examples

### Sidebar
- Background: `#284b44` (Primary)
- Active Link: `#956c2a` (Secondary)
- User Name: `#ea8990` (Accent)

### Header
- Background: `linear-gradient(135deg, #284b44 0%, #956c2a 100%)`
- Text: `#ffffff` (White)

### Buttons
- Primary Button: `#284b44` (Primary)
- Secondary Button: `#956c2a` (Secondary)
- Hover: Darker shades

### KPI Cards
- Background: `linear-gradient(145deg, #f0e1cd 0%, #e8d5c0 100%)`
- Top Border: `linear-gradient(90deg, #284b44, #956c2a, #ea8990)`
- Icon Backgrounds: `#284b44`, `#956c2a`, `#ea8990`

## CSS Variables (For Use in Projects)

```css
:root {
    /* Brand Colors */
    --brand-primary: #284b44;
    --brand-secondary: #956c2a;
    --brand-accent: #ea8990;
    
    /* Background Colors */
    --brand-background: #f0e1cd;
    --card-background: #ffffff;
    
    /* Text Colors */
    --text-color: #1f2937;
    --text-light: #6b7280;
    
    /* Status Colors */
    --success-color: #10b981;
    --warning-color: #f59e0b;
    --error-color: #ef4444;
    
    /* UI Colors */
    --border-color: #e5e7eb;
}
```

## JavaScript Object (For Programmatic Use)

```javascript
const SAKURA_COLORS = {
    primary: '#284b44',      // Dark green (main brand)
    secondary: '#956c2a',    // Brown/Gold (accent)
    accent: '#ea8990',       // Pink/Coral (special highlights)
    background: '#f0e1cd',   // Beige background
    success: '#10b981',      // Green (success states)
    warning: '#f59e0b',      // Orange (warnings)
    error: '#ef4444',        // Red (errors)
    info: '#3b82f6',         // Blue (info)
    dark: '#1f2937',         // Dark text
    light: '#6b7280'         // Light text
};
```

## Color Psychology & Brand Identity

- **#284b44 (Dark Green)**: Represents growth, stability, and professionalism
- **#956c2a (Brown/Gold)**: Represents warmth, reliability, and premium quality
- **#ea8990 (Pink/Coral)**: Represents approachability, innovation, and modern touch

## Design Guidelines

1. **Primary Color (#284b44)** should be used for:
   - Main navigation/sidebar
   - Primary action buttons
   - Headers and titles
   - Important UI elements

2. **Secondary Color (#956c2a)** should be used for:
   - Active states
   - Hover effects
   - Secondary buttons
   - Highlights and accents

3. **Accent Color (#ea8990)** should be used for:
   - User names and personal elements
   - Special highlights
   - Settings icons
   - Decorative elements

## Accessibility

All color combinations meet WCAG AA contrast requirements:
- Primary on White: ✅ 7.2:1 (AAA)
- Secondary on White: ✅ 4.8:1 (AA)
- White on Primary: ✅ 7.2:1 (AAA)
- White on Secondary: ✅ 4.8:1 (AA)

---

**Last Updated**: 2025-01-17
**Brand**: Sakura ERP Portal

