import type { Environment } from 'vitest/environments'

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
