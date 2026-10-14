import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// docker compose 에서는 VITE_API_TARGET=http://api:8000 으로 덮어쓴다.
const target = process.env.VITE_API_TARGET || 'http://localhost:8000';

export default defineConfig({
  // GitHub Pages 미리보기는 하위 경로(/newlake/)에 올라가므로 상대 경로로 빌드한다
  base: process.env.VITE_BASE || '/',
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    proxy: { '/api': { target, changeOrigin: true } },
  },
  preview: { port: 5173, proxy: { '/api': { target, changeOrigin: true } } },
});
