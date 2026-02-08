/**
 * ESLint Rules for i18n Pattern Enforcement
 * 
 * This configuration prevents hardcoded strings and enforces the locked i18n pattern.
 * 
 * Usage:
 * 1. Add to your main .eslintrc.js:
 *    extends: ['./.eslintrc-i18n.js']
 * 
 * 2. Or run separately:
 *    eslint --config .eslintrc-i18n.js src/
 */

module.exports = {
  rules: {
    // Prevent hardcoded strings in templates (requires vue-eslint-parser)
    'vue/no-v-text-v-html-on-component': 'error',
    
    // Custom rule: Warn about common hardcoded string patterns
    'no-restricted-syntax': [
      'warn',
      {
        selector: 'Literal[value=/^(Save|Cancel|Edit|Delete|Add|Close|Search|Filter|Actions|View|Previous|Next|All|Yes|No|Loading|No data|Error|Success|Warning)$/i]',
        message: 'Hardcoded UI string detected. Use $t(\'common.key\') or t(\'namespace.key\') instead. See GRNs.vue for reference.'
      },
      {
        selector: 'Property[key.name="placeholder"][value.type="Literal"]',
        message: 'Hardcoded placeholder detected. Use :placeholder="$t(\'key\')" instead.'
      },
      {
        selector: 'Property[key.name="title"][value.type="Literal"]',
        message: 'Hardcoded title detected. Use :title="$t(\'key\')" instead.'
      }
    ],
    
    // Prevent direct use of old translation system
    'no-restricted-imports': [
      'error',
      {
        paths: [
          {
            name: '@/utils/translations',
            message: 'Old translation system is deprecated. Use useI18n() from @/composables/useI18n instead. See GRNs.vue for reference.'
          }
        ],
        patterns: [
          {
            group: ['**/utils/translations*'],
            message: 'Old translation system is deprecated. Use useI18n() from @/composables/useI18n instead.'
          }
        ]
      }
    ]
  },
  
  overrides: [
    {
      files: ['*.vue'],
      rules: {
        // Additional Vue-specific rules can be added here
      }
    }
  ]
};

