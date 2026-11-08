import svelte from 'eslint-plugin-svelte';
import tseslint from 'typescript-eslint';

import { parserOptions } from './shared.js';

export const svelteFiles = [
  ...svelte.configs.base,
  {
    name: 'nrdrm/svelte',
    files: ['**/*.svelte'],
    languageOptions: {
      parserOptions: {
        ...parserOptions,
        parser: tseslint.parser,
        extraFileExtensions: ['.svelte'],
      },
    },
    rules: {
      curly: ['error', 'all'],
    },
  },
];
