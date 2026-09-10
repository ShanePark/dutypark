import type { Environment } from 'vitest/runtime'

const environment: Environment = {
  name: 'vue-client-host',
  viteEnvironment: 'client',
  setup() {
    return {
      teardown() {},
    }
  },
}

export default environment
