import { fixupPluginRules } from '@eslint/compat';
import js from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import reactPlugin from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';
import tseslint from 'typescript-eslint';

import { ignorePatterns } from './ignores.js';
import {
  parserOptions,
  importSettings,
  sharedPlugins,
  sharedRules,
  sharedOverrides,
} from './shared.js';

const reactPluginFixed = fixupPluginRules(reactPlugin);
const jsxA11yFixed = fixupPluginRules(jsxA11y);

export const react = tseslint.config(
  { ignores: ignorePatterns },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  eslintConfigPrettier,
  {
    name: 'nrdrm/react',
    files: ['**/*.{js,jsx,cjs,mjs,ts,tsx}'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ...parserOptions,
        ecmaFeatures: {
          jsx: true,
        },
      },
      globals: {
        ...globals.browser,
        ...globals.node,
        RequestInit: 'readonly',
        NodeJS: 'readonly',
        JSX: 'readonly',
        React: 'readonly',
      },
    },
    plugins: {
      ...sharedPlugins,
      react: reactPluginFixed,
      'react-hooks': reactHooks,
      'jsx-a11y': jsxA11yFixed,
    },
    settings: {
      ...importSettings,
      react: {
        version: 'detect',
      },
    },
    rules: {
      ...reactPlugin.configs.flat.recommended.rules,
      ...jsxA11y.flatConfigs.recommended.rules,
      ...sharedRules,
      'react/jsx-key': 'error',
      'react/react-in-jsx-scope': 'off',
      'react/jsx-uses-react': 'off',
      'react/require-render-return': 'off',
      'react/no-direct-mutation-state': 'off',
      'react/display-name': 'off',
      'react/prop-types': 'off',
      'react/no-unstable-nested-components': ['error', { allowAsProps: true }],
      'react/no-array-index-key': 'error',
      'jsx-a11y/alt-text': [
        'error',
        {
          elements: ['img', 'object', 'area', 'input[type="image"]'],
          img: ['Image'],
          object: [],
          area: [],
          'input[type="image"]': [],
        },
      ],
      'jsx-a11y/label-has-associated-control': [
        'error',
        {
          labelComponents: [],
          labelAttributes: [],
          controlComponents: ['Input'],
          depth: 25,
        },
      ],
      'jsx-a11y/anchor-is-valid': 'off',
      'jsx-a11y/no-autofocus': 'off',
      'react/no-unknown-property': [
        'error',
        {
          ignore: [
            'fill-rule',
            'clip-rule',
            'stroke-width',
            'clip-path',
            'cmdk-input-wrapper',
          ],
        },
      ],
      'react/jsx-filename-extension': [
        'error',
        { extensions: ['.jsx', '.tsx'] },
      ],
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'error',
    },
  },
  ...sharedOverrides,
);
