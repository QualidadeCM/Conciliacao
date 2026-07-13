// Tipos TypeScript correspondentes ao schema do Supabase.
// Quando alterar o schema.sql, atualize estes tipos ou rode `supabase gen types typescript`.

export type AnaliseStatus = 'em_andamento' | 'conforme' | 'ressalva' | 'nao_conforme';

export type TipoDocumento =
  | 'op'
  | 'rc'
  | 'form_gq_0047'
  | 'etiqueta_externa'
  | 'etiqueta_acessorio'
  | 'op_reprocesso'
  | 'rnc';

export type TipoControle = 'serie' | 'lote';
export type MarcacaoForm = 'SIM' | 'NAO' | 'N/A';
export type SeveridadeApontamento = 'conforme' | 'ressalva' | 'nao_conforme';

export interface Produto {
  id: string;
  equipamento: string;
  modelo: string;
  codigo_referencia: string;
  registro_anvisa: string;
  codigo_sapiens: string | null;
  derivacao: string | null;
  ativo: boolean;
  created_at: string;
  updated_at: string;
}

export interface FichaMestre {
  id: string;
  produto_id: string;
  versao: number;
  ativa: boolean;
  familia: string | null;
  nome_comercial: string | null;
  convencao_nro_serie: string | null;
  exemplo_nro_serie: string | null;
  aplicacao_clinica: string | null;
  data_concessao_anvisa: string | null;
  aplicabilidade_udi: string | null;
  inmetro_aplicavel: boolean;
  inmetro_observacao: string | null;
  razao_social: string | null;
  cnpj: string | null;
  endereco_fabrica: string | null;
  telefone: string | null;
  responsavel_tecnico: string | null;
  crea_rt: string | null;
  responsavel_legal: string | null;
  etiqueta_externa_campos: Record<string, unknown>;
  regras_negocio: Array<{ regra: string }>;
  observacoes: string | null;
  created_at: string;
  updated_at: string;
  created_by: string | null;
}

export interface AcessorioAplicavel {
  id: string;
  ficha_id: string;
  ordem: number;
  descricao: string;
  codigo_sapiens: string;
  obrigatorio: boolean;
  is_fabricante_confiance: boolean;
  esteril: boolean;
  observacao: string | null;
}

export interface RoteiroFormGq0047 {
  id: string;
  ficha_id: string;
  ordem: number;
  item_checklist: string;
  marcacao_esperada: MarcacaoForm;
  justificativa: string | null;
}

export interface InspecaoCriterio {
  id: string;
  ficha_id: string;
  estagio_codigo: string;
  estagio_nome: string;
  criterio_aceitacao: string;
}

export interface ComponenteBom {
  id: string;
  ficha_id: string;
  codigo_sapiens: string;
  descricao: string;
  tipo_controle: TipoControle;
  prefixo_serie: string | null;
  quantidade: number;
  critico: boolean;
  observacao: string | null;
}

export interface Analise {
  id: string;
  produto_id: string | null;
  ficha_id: string | null;
  numero_op: string | null;
  numero_serie: string | null;
  nome_produto: string | null;
  modelo: string | null;
  registro_anvisa: string | null;
  status: AnaliseStatus;
  parecer_resumo: string | null;
  parecer_completo: unknown;
  iniciada_em: string;
  finalizada_em: string | null;
  tempo_execucao_ms: number | null;
  created_by: string | null;
  created_at: string;
}

export interface DocumentoAnalise {
  id: string;
  analise_id: string;
  tipo: TipoDocumento;
  nome_arquivo: string;
  storage_path: string;
  tamanho_bytes: number | null;
  texto_extraido: string | null;
  created_at: string;
}

export interface Apontamento {
  id: string;
  analise_id: string;
  ordem: number;
  codigo: string | null;
  severidade: SeveridadeApontamento;
  camada: number;
  documento_afetado: string | null;
  referencia_normativa: string | null;
  descricao: string;
  recomendacao: string | null;
}

// Tipo agregado que o Supabase JS espera
export type Database = {
  public: {
    Tables: {
      produtos: { Row: Produto; Insert: Partial<Produto>; Update: Partial<Produto> };
      fichas_mestres: { Row: FichaMestre; Insert: Partial<FichaMestre>; Update: Partial<FichaMestre> };
      acessorios_aplicaveis: { Row: AcessorioAplicavel; Insert: Partial<AcessorioAplicavel>; Update: Partial<AcessorioAplicavel> };
      roteiro_form_gq_0047: { Row: RoteiroFormGq0047; Insert: Partial<RoteiroFormGq0047>; Update: Partial<RoteiroFormGq0047> };
      inspecoes_criterios: { Row: InspecaoCriterio; Insert: Partial<InspecaoCriterio>; Update: Partial<InspecaoCriterio> };
      componentes_bom: { Row: ComponenteBom; Insert: Partial<ComponenteBom>; Update: Partial<ComponenteBom> };
      analises: { Row: Analise; Insert: Partial<Analise>; Update: Partial<Analise> };
      documentos_analise: { Row: DocumentoAnalise; Insert: Partial<DocumentoAnalise>; Update: Partial<DocumentoAnalise> };
      apontamentos: { Row: Apontamento; Insert: Partial<Apontamento>; Update: Partial<Apontamento> };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: {
      analise_status: AnaliseStatus;
      tipo_documento: TipoDocumento;
      tipo_controle: TipoControle;
      marcacao_form: MarcacaoForm;
      severidade_apontamento: SeveridadeApontamento;
    };
  };
};
