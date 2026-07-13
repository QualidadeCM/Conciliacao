import { CheckCircle2, AlertTriangle, XCircle, Clock } from 'lucide-react';
import { cn } from '@/lib/utils';

export type AnaliseStatus = 'conforme' | 'ressalva' | 'nao_conforme' | 'em_andamento';

interface StatusBadgeProps {
  status: AnaliseStatus;
  className?: string;
}

const config: Record<AnaliseStatus, { label: string; classes: string; Icon: typeof CheckCircle2 }> = {
  conforme: {
    label: 'Conforme',
    classes: 'status-badge-conforme',
    Icon: CheckCircle2,
  },
  ressalva: {
    label: 'Conforme com Ressalvas',
    classes: 'status-badge-ressalva',
    Icon: AlertTriangle,
  },
  nao_conforme: {
    label: 'Não Conforme',
    classes: 'status-badge-nao-conforme',
    Icon: XCircle,
  },
  em_andamento: {
    label: 'Em análise',
    classes: 'bg-muted text-muted-foreground',
    Icon: Clock,
  },
};

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const { label, classes, Icon } = config[status];
  return (
    <span className={cn('status-badge', classes, className)}>
      <Icon className="h-3.5 w-3.5" />
      {label}
    </span>
  );
}
