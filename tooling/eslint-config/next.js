import nextPlugin from '@next/eslint-plugin-next';
import tseslint from 'typescript-eslint';

import { react } from './react.js';

export const next = tseslint.config(...react, {
  name: 'nrdrm/next',
  files: ['**/*.{js,jsx,cjs,mjs,ts,tsx}'],
  plugins: {
    '@next/next': nextPlugin,
  },
  rules: {
    ...nextPlugin.configs['core-web-vitals'].rules,
    // This repo's Next app uses the app router and has no pages directory.
    '@next/next/no-html-link-for-pages': 'off',
  },
});
