import { PageHeader } from '@/components/PageHeader';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { StatusBadge } from '@/components/StatusBadge';
import { CheckCircle2, AlertTriangle, XCircle, Activity, BarChart3 } from 'lucide-react';

export function DashboardPage() {
  return (
    <div>
      <PageHeader
        title="Dashboard"
        description="Visão geral das conciliações de produção analisadas pelo agente."
      />

      {/* Cards de métrica - aguardando integração com Supabase */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <MetricCard
          icon={Activity}
          label="Total de análises"
          value="—"
          hint="aguardando dados"
        />
        <MetricCard
          icon={CheckCircle2}
          label="Conforme"
          value="—"
          hint="aguardando dados"
          accent="conforme"
        />
        <MetricCard
          icon={AlertTriangle}
          label="Com ressalvas"
          value="—"
          hint="aguardando dados"
          accent="ressalva"
        />
        <MetricCard
          icon={XCircle}
          label="Não conforme"
          value="—"
          hint="aguardando dados"
          accent="nao_conforme"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="h-5 w-5 text-accent" />
              Análises por mês
            </CardTitle>
            <CardDescription>
              Histórico mensal — disponível após a primeira análise registrada.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-64 flex items-center justify-center text-sm text-muted-foreground border border-dashed rounded-lg">
              Aguardando dados das análises (Fase 4)
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Top produtos analisados</CardTitle>
            <CardDescription>Distribuição por modelo.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3 text-sm text-muted-foreground">
              <p>Aguardando dados das análises (Fase 4)</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card className="mt-4">
        <CardHeader>
          <CardTitle>Últimas análises</CardTitle>
          <CardDescription>5 análises mais recentes do histórico.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-sm text-muted-foreground">
            Aguardando dados das análises (Fase 4)
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function MetricCard({
  icon: Icon,
  label,
  value,
  hint,
  accent,
}: {
  icon: typeof CheckCircle2;
  label: string;
  value: string;
  hint?: string;
  accent?: 'conforme' | 'ressalva' | 'nao_conforme';
}) {
  const accentClass =
    accent === 'conforme'
      ? 'text-status-conforme'
      : accent === 'ressalva'
        ? 'text-status-ressalva'
        : accent === 'nao_conforme'
          ? 'text-status-nao-conforme'
          : 'text-accent';

  return (
    <Card>
      <CardContent className="pt-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="text-xs uppercase tracking-wide text-muted-foreground font-semibold">
              {label}
            </div>
            <div className="mt-2 font-montserrat text-3xl font-bold">{value}</div>
            {hint && <div className="mt-1 text-xs text-muted-foreground">{hint}</div>}
          </div>
          <Icon className={`h-6 w-6 ${accentClass}`} />
        </div>
      </CardContent>
    </Card>
  );
}
