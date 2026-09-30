// Regenerate the self-contained review file with: npm run duty-colors:review
import { build } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath } from 'node:url'
import { mkdir, writeFile } from 'node:fs/promises'
const root = fileURLToPath(new URL('../../', import.meta.url))
const result = await build({
  configFile: false, root, define: { 'process.env.NODE_ENV': JSON.stringify('production') }, plugins: [vue(), tailwindcss()],
  resolve: { alias: { '@': `${root}src` } },
  build: { write: false, assetsInlineLimit: Infinity, cssCodeSplit: false, lib: { entry: `${root}tools/duty-color-review/main.ts`, name: 'DutyColorReview', formats: ['iife'] } },
})
const output = (Array.isArray(result) ? result : [result]).flatMap(r => r.output)
const script = output.filter(f => f.type === 'chunk').map(f => f.code).join('\n').replace(/<\/script/gi, '<\\/script')
const css = output.filter(f => f.type === 'asset' && f.fileName.endsWith('.css')).map(f => f.source).join('\n')
if (/url\((?!["']?data:)/.test(css)) throw new Error('Review CSS contains external assets')
const html = `<!doctype html><html lang="ko"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dutypark 최종 팔레트 미리보기</title><style>${css}</style></head><body><div id="app"></div><script>${script}</script></body></html>`
for (const path of [`${root}../docs/duty-color-review.html`, `${root}public/duty-color-review.html`]) {
  await mkdir(fileURLToPath(new URL('.', `file://${path}`)), { recursive: true })
  await writeFile(path, html)
  console.log(`Generated ${path}`)
}
