import { PageHeader } from '@/components/PageHeader';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';

export function HistoricoPage() {
  return (
    <div>
      <PageHeader
        title="Histórico de análises"
        description="Consulta de todas as conciliações já executadas pelo agente."
      />

      <Card>
        <CardHeader>
          <CardTitle>Análises registradas</CardTitle>
          <CardDescription>
            Filtre por produto, OP, número de série, data ou resultado.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="rounded-lg border border-dashed p-12 text-center">
            <p className="text-sm text-muted-foreground">
              Nenhuma análise registrada ainda.
            </p>
            <p className="text-xs text-muted-foreground mt-1">
              A listagem completa será implementada na <strong>Fase 4</strong>.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
