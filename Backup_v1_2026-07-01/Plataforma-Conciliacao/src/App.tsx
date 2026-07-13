import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'sonner';
import { ThemeProvider } from '@/contexts/ThemeProvider';
import { AppLayout } from '@/components/layout/AppLayout';
import { DashboardPage } from '@/pages/Dashboard';
import { AnalisePage } from '@/pages/Analise';
import { HistoricoPage } from '@/pages/Historico';
import { CadastroPage } from '@/pages/Cadastro';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      refetchOnWindowFocus: false,
    },
  },
});

export default function App() {
  return (
    <ThemeProvider>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <Routes>
            <Route element={<AppLayout />}>
              <Route path="/" element={<DashboardPage />} />
              <Route path="/analise" element={<AnalisePage />} />
              <Route path="/historico" element={<HistoricoPage />} />
              <Route path="/cadastro" element={<CadastroPage />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Route>
          </Routes>
        </BrowserRouter>
        <Toaster richColors closeButton position="top-right" />
      </QueryClientProvider>
    </ThemeProvider>
  );
}
