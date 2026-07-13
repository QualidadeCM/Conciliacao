import { PageHeader } from '@/components/PageHeader';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { FileSearch, Upload, AlertCircle } from 'lucide-react';

export function AnalisePage() {
  return (
    <div>
      <PageHeader
        title="Nova análise"
        description="Faça upload dos documentos do lote para que o agente execute a conciliação seguindo o protocolo v1.1."
      />

      <Card className="border-dashed border-accent/30 bg-accent/5 mb-6">
        <CardContent className="pt-6">
          <div className="flex items-start gap-3">
            <AlertCircle className="h-5 w-5 text-accent mt-0.5 shrink-0" />
            <div className="text-sm text-foreground">
              <strong className="font-semibold">Fase 1 — Fundação.</strong> A tela de upload e
              execução do agente será implementada na <strong>Fase 3</strong>. Por enquanto, a estrutura
              de navegação e os tipos de documento já estão definidos abaixo.
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Bloco Obrigatórios */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Upload className="h-5 w-5 text-accent" />
              Documentos obrigatórios
            </CardTitle>
            <CardDescription>
              Sem estes 4 arquivos a análise não pode ser executada.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <UploadSlot label="Ordem de Produção (OP)" formats="PDF" />
              <UploadSlot label="Relação de Componentes (RC)" formats="PDF" />
              <UploadSlot label="FORM-GQ-0047 preenchido" formats="PDF" />
              <UploadSlot label="Etiqueta Externa do Produto Acabado" formats="DOCX" />
            </div>
          </CardContent>
        </Card>

        {/* Bloco Opcionais */}
        <Card>
          <CardHeader>
            <CardTitle>Documentos opcionais</CardTitle>
            <CardDescription>Anexe quando aplicáveis.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <UploadSlot
                label="Etiquetas de Acessórios"
                formats="DOCX · múltiplas"
                disabled
              />
              <UploadSlot label="OP de Reprocesso" formats="PDF" disabled />
              <UploadSlot label="RNC associada" formats="PDF" disabled />
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="mt-6 flex justify-end">
        <Button size="lg" disabled className="gap-2">
          <FileSearch className="h-4 w-4" />
          Analisar lote
        </Button>
      </div>
    </div>
  );
}

function UploadSlot({
  label,
  formats,
  disabled,
}: {
  label: string;
  formats: string;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-lg border border-dashed p-3">
      <div>
        <div className="text-sm font-medium">{label}</div>
        <div className="text-xs text-muted-foreground">{formats}</div>
      </div>
      <Button variant="outline" size="sm" disabled={disabled}>
        <Upload className="h-3.5 w-3.5" />
        Selecionar arquivo
      </Button>
    </div>
  );
}
