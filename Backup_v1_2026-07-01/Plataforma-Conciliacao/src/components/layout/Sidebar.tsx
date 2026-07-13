import { NavLink } from 'react-router-dom';
import { LayoutDashboard, FileSearch, History, Database, Moon, Sun } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useTheme } from '@/contexts/ThemeProvider';
import { Button } from '@/components/ui/button';

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/analise', label: 'Análise', icon: FileSearch },
  { to: '/historico', label: 'Histórico', icon: History },
  { to: '/cadastro', label: 'Cadastro', icon: Database },
];

export function Sidebar() {
  const { resolvedTheme, setTheme } = useTheme();

  return (
    <aside className="flex h-screen w-64 flex-col bg-sidebar text-sidebar-foreground border-r border-sidebar-border">
      {/* Logo / Header */}
      <div className="flex items-center gap-3 px-6 py-6 border-b border-sidebar-border">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-accent">
          <span className="font-montserrat font-bold text-accent-foreground text-lg">C</span>
        </div>
        <div className="flex flex-col">
          <span className="font-montserrat font-bold text-base leading-tight">
            Confiance
          </span>
          <span className="text-xs text-sidebar-foreground/70 leading-tight">
            Medical
          </span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1">
        <div className="px-3 pb-2 text-xs uppercase tracking-wider text-sidebar-foreground/50 font-semibold">
          Conciliação da Produção
        </div>
        {navItems.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                  : 'text-sidebar-foreground/80 hover:bg-sidebar-accent/60 hover:text-sidebar-foreground'
              )
            }
          >
            <Icon className="h-4 w-4" />
            {label}
          </NavLink>
        ))}
      </nav>

      {/* Footer */}
      <div className="border-t border-sidebar-border p-4 space-y-3">
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
          className="w-full justify-start text-sidebar-foreground/80 hover:bg-sidebar-accent/60 hover:text-sidebar-foreground"
        >
          {resolvedTheme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          {resolvedTheme === 'dark' ? 'Modo claro' : 'Modo escuro'}
        </Button>
        <div className="px-2 text-xs text-sidebar-foreground/60">
          <div className="font-medium">qualidade@confiancemedical.com.br</div>
          <div className="mt-1 text-[10px] uppercase tracking-wider text-sidebar-foreground/40">
            Garantia da Qualidade
          </div>
        </div>
      </div>
    </aside>
  );
}
