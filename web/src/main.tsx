import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, HashRouter } from 'react-router-dom';
import App from './App';
import { AuthProvider } from './auth';
import 'pretendard/dist/web/variable/pretendardvariable-dynamic-subset.css';
import './styles.css';

// 미리보기(GitHub Pages)는 정적 호스팅이라 새로고침해도 경로가 살도록 해시 라우팅을 쓴다
const Router = import.meta.env.VITE_DEMO === '1' ? HashRouter : BrowserRouter;

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Router>
      <AuthProvider>
        <App />
      </AuthProvider>
    </Router>
  </StrictMode>,
);
