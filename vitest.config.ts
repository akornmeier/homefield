import { defineConfig } from 'vitest/config'
import { defineVitestProject } from '@nuxt/test-utils/config'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '~': resolve(__dirname, './app'),
      '@': resolve(__dirname, './app'),
    },
  },
  test: {
    globals: true,
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          include: ['tests/unit/**/*.test.ts'],
          environment: 'node',
        },
      },
      defineVitestProject({
        test: {
          name: 'component',
          include: ['tests/component/**/*.test.ts'],
          environmentOptions: {
            nuxt: {
              rootDir: '.',
            },
          },
        },
      }),
      {
        extends: true,
        test: {
          name: 'integration',
          include: ['tests/integration/**/*.test.ts'],
          environment: 'node', // @nuxt/test-utils/e2e manages its own browser
          setupFiles: ['tests/setup/integration.ts'],
        },
      },
    ],
  },
})
