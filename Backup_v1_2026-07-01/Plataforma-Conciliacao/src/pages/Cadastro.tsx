import { PageHeader } from '@/components/PageHeader';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Plus, BookOpen, Package } from 'lucide-react';

export function CadastroPage() {
  return (
    <div>
      <PageHeader
        title="Cadastro"
        description="Catálogo de produtos (FORM-GQ-0085) e Fichas Mestres usadas pelo agente como base de conhecimento."
        actions={
          <Button disabled className="gap-2">
            <Plus className="h-4 w-4" />
            Novo cadastro
          </Button>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Package className="h-5 w-5 text-accent" />
              Catálogo de Produtos
            </CardTitle>
            <CardDescription>
              Espelha o FORM-GQ-0085: Equipamento, Modelo, Código de Referência e Registro ANVISA.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-lg border border-dashed p-8 text-center">
              <p className="text-sm text-muted-foreground">CRUD completo na <strong>Fase 2</strong>.</p>
              <p className="text-xs text-muted-foreground mt-1">
                A seed inicial trará todos os produtos do FORM-GQ-0085.
              </p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BookOpen className="h-5 w-5 text-accent" />
              Fichas Mestres
            </CardTitle>
            <CardDescription>
              Espelham a Ficha Mestre do CM-LED: 9 seções com identificação, etiqueta, acessórios,
              roteiro do FORM-GQ-0047, inspeções, BOM e regras de negócio.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-lg border border-dashed p-8 text-center">
              <p className="text-sm text-muted-foreground">Editor completo na <strong>Fase 2</strong>.</p>
              <p className="text-xs text-muted-foreground mt-1">
                Versionamento mantido (auditoria ISO 13485).
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
