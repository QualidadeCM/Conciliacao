# Auditoria — tempo de execução dos Estágios 5 e 50 (Julho e Agosto/2026)

**Data:** 17/08/2026
**Escopo:** pasta "Pendente de Assinatura" — meses de JULHO e AGOSTO/2026 (230 OPs).
**Regra:** desvio maior que 50% (para mais ou para menos) da média esperada gera apontamento.
Médias: Estágio 5 = 7 min (endoscópio rígido) / 25 min (demais); Estágio 50 = 5 min (rígido) / 17 min (demais).

**Classificação rígido × demais:** feita pelo código de referência da série de cada OP,
cruzando com o catálogo FORM-GQ-0085. São endoscópios rígidos os códigos
**LAP, ART, NAS, NEF, URE, CIS, HIS**; o restante usa a média "demais".

## Resumo

- **230 OPs** auditadas (172 julho, 58 agosto).
- **143 OPs** com ao menos um estágio fora da margem.
- **Estágio 5:** 106 dentro · 111 acima · 13 abaixo.
- **Estágio 50:** 108 dentro · 112 acima · 10 abaixo.

## Observação importante — calibração das médias

Comparando as médias configuradas com o tempo real observado (mediana), aparece um
descompasso grande justamente nos endoscópios rígidos:

| Grupo | Estágio | Média configurada | Mediana observada |
|---|---|---|---|
| Endoscópio rígido | 5 | 7 min | ~20 min |
| Endoscópio rígido | 50 | 5 min | ~20 min |
| Demais equipamentos | 5 | 25 min | ~25 min |
| Demais equipamentos | 50 | 17 min | ~20 min |

Para os **demais equipamentos** as médias batem bem com a realidade. Já para os
**endoscópios rígidos**, o tempo real (mediana ~20 min) é bem acima da média
configurada (7/5 min) — por isso quase todos os rígidos aparecem "acima da margem".
Vale revisar se as médias de 7/5 min estão corretas para esses produtos ou se há
mesmo um problema sistemático de apontamento de fim de estágio neles.

> Nota: na análise dentro da plataforma, a classificação de rígido usa o campo
> "Equipamento" da Ficha Mestre (que contém "ENDOSCÓPIO RÍGIDO PARA ..."), então
> funciona corretamente. Esta auditoria usou o código da série + catálogo para
> chegar ao mesmo resultado fora do sistema.

---

## Estágio 5 — fora da margem

| Mês | OP | Tipo | Tempo | Faixa | Desvio | Operador |
|---|---|---|---|---|---|---|
| AGOSTO | 7655_CM40T-20267-2 | outros | 188min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7694_SC34KT-20267-1 | outros | 60min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| AGOSTO | 7696_LEDT-20267-11 | outros | 149min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7697_LEDT-20267-12 | outros | 149min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7699_LEDT-20267-14 | outros | 149min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7700_LEDT-20267-15 | outros | 149min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7706_SC34KT-20267-2 | outros | 56min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7712_CM32FC-20267-23 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| AGOSTO | 7713_CM32FC-20267-24 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| AGOSTO | 7714_CM32FC-20267-25 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| AGOSTO | 7715_CM32FC-20267-26 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| AGOSTO | 7717_REC3UHD-20267-1 | outros | 111min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| AGOSTO | 7721_LEDT-20267-16 | outros | 75min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7722_LEDT-20267-17 | outros | 74min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7723_LEDT-20267-18 | outros | 74min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7725_LEDT-20267-20 | outros | 74min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7736_CMST-20267-4 | outros | 218min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| AGOSTO | 7737_CMST-20267-5 | outros | 218min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| AGOSTO | 7739_SC4KT-20267-6 | outros | 61min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7740_SC4KT-20267-7 | outros | 61min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7741_SC4KT-20267-8 | outros | 61min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7742_SC4KT-20267-9 | outros | 61min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7746_LAP51-20267-14 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7747_LAP51-20267-15 | rígido | 25min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7749_LAP51-20267-17 | rígido | 34min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7750_LAP51-20267-18 | rígido | 39min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7758_SC4KT-20267-10 | outros | 76min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7760_SC4KT-20267-12 | outros | 12min | (média 25, faixa 12.5-37.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7761_SC4KT-20267-13 | outros | 12min | (média 25, faixa 12.5-37.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7763_SC4KT-20267-15 | outros | 12min | (média 25, faixa 12.5-37.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7766_SC4KT-20267-18 | outros | 12min | (média 25, faixa 12.5-37.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7768_SC3FHDT-20267-2 | outros | 45min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7769_SC3FHDT-20267-3 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7778_CMFLOW-20267-7 | outros | 183min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| AGOSTO | 7784_SC4KT-20267-20 | outros | 39min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| AGOSTO | 7820_LAP51-20268-1 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7821_LAP51-20268-2 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7823_LAP51-20268-4 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7824_LAP51-20268-5 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7825_LAP51-20268-6 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7826_LAP51-20268-7 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7827_LAP51-20268-8 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7828_LAP51-20268-9 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| AGOSTO | 7829_LAP51-20268-10 | rígido | 3min | (média 7, faixa 3.5-10.5) | ABAIXO | Kaiky Nascimento |
| JULHO | 7399_CM32FC-20265-18 | outros | 90min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| JULHO | 7404_CM32FC-20265-9 | outros | 55min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7405_CM32FC-20265-10 | outros | 54min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7500_LAP51-20266-1 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7501_LAP51-20266-2 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7502_LAP51-20266-3 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7503_LAP51-20266-4 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7504_LAP51-20266-5 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7526_HIS28-20266-4 | rígido | 35min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7528_HIS28-20266-6 | rígido | 35min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7529_HIS28-20266-7 | rígido | 34min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7530_HIS28-20266-8 | rígido | 34min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7568_SC4KT-20266-6 | outros | 60min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Feno |
| JULHO | 7570_LAP51-20266-6 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7571_LAP51-20266-7 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7572_LAP51-20266-8 | rígido | 29min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7573_LAP51-20266-9 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7574_LAP51-20266-10 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7575_LAP51-20266-11 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7576_LAP51-20266-12 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7578_LAP51-20266-14 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7579_LAP51-20266-15 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7580_LAP51-20266-16 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7581_LAP51-20266-17 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7582_LAP51-20266-18 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7583_LAP51-20266-19 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7584_LAP51-20266-20 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7585_LAP51-20266-21 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7586_LAP51-20266-22 | rígido | 23min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7587_LAP51-20266-23 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7588_LAP51-20266-24 | rígido | 23min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7589_LAP51-20266-25 | rígido | 23min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7590_SC3FHDT-20266-1 | outros | 42min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7601_LAP51-20266-26 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7602_LAP51-20266-27 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7603_LAP51-20266-28 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7604_LAP51-20266-29 | rígido | 25min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7605_LAP51-20266-30 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7606_LAP51-20266-31 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7607_LAP51-20266-32 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7608_LAP51-20266-33 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7609_LAP51-20266-34 | rígido | 24min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7611_ART11-20266-1 | rígido | 18min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7612_CIS28-20266-7 | rígido | 23min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7614_ART10-20266-1 | rígido | 18min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7626_HIS28-20266-12 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7650_NAS20-20267-1 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7659_LAP51-20267-1 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7660_LAP51-20267-2 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7661_LAP51-20267-3 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7662_LAP51-20267-4 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7663_LAP51-20267-5 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7664_LAP51-20267-6 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7665_LAP51-20267-7 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7666_LAP51-20267-8 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7667_LAP51-20267-9 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7668_LAP51-20267-10 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Milla Gomes |
| JULHO | 7670_LEDT-20267-7 | outros | 78min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7672_LEDT-20267-9 | outros | 78min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7673_LEDT-20267-10 | outros | 78min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7682_CM32FC-20267-19 | outros | 100min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| JULHO | 7683_CM32FC-20267-20 | outros | 100min | (média 25, faixa 12.5-37.5) | ACIMA | Milla Gomes |
| JULHO | 7689_CM27FC-20267-1 | outros | 47min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7691_SC4KT-20267-3 | outros | 43min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7692_SC4KT-20267-4 | outros | 43min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7708_SC34KT-20267-4 | outros | 57min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7709_CM32FC-20267-21 | outros | 72min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7710_CM32FC-20267-22 | outros | 72min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7718_HIS33-20267-1 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7719_HIS33-20267-2 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7720_HIS33-20267-3 | rígido | 20min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Silva |
| JULHO | 7733_CMST-20267-1 | outros | 217min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7734_CMST-20267-2 | outros | 218min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7735_CMST-20267-3 | outros | 218min | (média 25, faixa 12.5-37.5) | ACIMA | Guilherme Silva |
| JULHO | 7738_SC4KT-20267-5 | outros | 61min | (média 25, faixa 12.5-37.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7745_LAP51-20267-13 | rígido | 15min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| JULHO | 7748_LAP51-20267-16 | rígido | 29min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| JULHO | 7751_LAP51-20267-19 | rígido | 44min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| JULHO | 7752_LAP51-20267-20 | rígido | 49min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |
| JULHO | 7756_NAS10-20267-1 | rígido | 19min | (média 7, faixa 3.5-10.5) | ACIMA | Guilherme Feno |

## Estágio 50 — fora da margem

| Mês | OP | Tipo | Tempo | Faixa | Desvio | Operador |
|---|---|---|---|---|---|---|
| AGOSTO | 7694_SC34KT-20267-1 | outros | 29min | (média 17, faixa 8.5-25.5) | ACIMA | Guilherme Silva |
| AGOSTO | 7696_LEDT-20267-11 | outros | 26min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7699_LEDT-20267-14 | outros | 6min | (média 17, faixa 8.5-25.5) | ABAIXO | André Afonso |
| AGOSTO | 7700_LEDT-20267-15 | outros | 6min | (média 17, faixa 8.5-25.5) | ABAIXO | André Afonso |
| AGOSTO | 7706_SC34KT-20267-2 | outros | 40min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7712_CM32FC-20267-23 | outros | 29min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7713_CM32FC-20267-24 | outros | 57min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7714_CM32FC-20267-25 | outros | 57min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7715_CM32FC-20267-26 | outros | 57min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7717_REC3UHD-20267-1 | outros | 34min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7721_LEDT-20267-16 | outros | 26min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7722_LEDT-20267-17 | outros | 42min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7723_LEDT-20267-18 | outros | 42min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7732_CMEND-20267-3 | outros | 30min | (média 17, faixa 8.5-25.5) | ACIMA | Kaiky Nascimento |
| AGOSTO | 7736_CMST-20267-4 | outros | 64min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7737_CMST-20267-5 | outros | 63min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7740_SC4KT-20267-7 | outros | 78min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7741_SC4KT-20267-8 | outros | 97min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7742_SC4KT-20267-9 | outros | 48min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7743_LAP51-20267-11 | rígido | 28min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7746_LAP51-20267-14 | rígido | 28min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7747_LAP51-20267-15 | rígido | 28min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7749_LAP51-20267-17 | rígido | 28min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7750_LAP51-20267-18 | rígido | 28min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7754_CMST27-20267-2 | outros | 58min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7755_CMST27-20267-3 | outros | 28min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7758_SC4KT-20267-10 | outros | 34min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7759_SC4KT-20267-11 | outros | 67min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7761_SC4KT-20267-13 | outros | 88min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7762_SC4KT-20267-14 | outros | 59min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7763_SC4KT-20267-15 | outros | 32min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7766_SC4KT-20267-18 | outros | 32min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7768_SC3FHDT-20267-2 | outros | 39min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7769_SC3FHDT-20267-3 | outros | 40min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7783_LAP60-20267-1 | rígido | 2min | (média 5, faixa 2.5-7.5) | ABAIXO | André Afonso |
| AGOSTO | 7784_SC4KT-20267-20 | outros | 48min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7815_SC3FHDT-20268-5 | outros | 50min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7818_SC3FHDT-20268-8 | outros | 50min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| AGOSTO | 7820_LAP51-20268-1 | rígido | 56min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7821_LAP51-20268-2 | rígido | 57min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7822_LAP51-20268-3 | rígido | 56min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7823_LAP51-20268-4 | rígido | 54min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7824_LAP51-20268-5 | rígido | 58min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7825_LAP51-20268-6 | rígido | 56min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7826_LAP51-20268-7 | rígido | 56min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7827_LAP51-20268-8 | rígido | 57min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7828_LAP51-20268-9 | rígido | 56min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| AGOSTO | 7829_LAP51-20268-10 | rígido | 55min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7359_SCFHDT-20265-6 | outros | 7min | (média 17, faixa 8.5-25.5) | ABAIXO | Thiago Oliveira |
| JULHO | 7393_CM32FC-20265-3 | outros | 28min | (média 17, faixa 8.5-25.5) | ACIMA | Thiago Oliveira |
| JULHO | 7399_CM32FC-20265-18 | outros | 106min | (média 17, faixa 8.5-25.5) | ACIMA | Thiago Oliveira |
| JULHO | 7500_LAP51-20266-1 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7501_LAP51-20266-2 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7502_LAP51-20266-3 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7503_LAP51-20266-4 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7504_LAP51-20266-5 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7526_HIS28-20266-4 | rígido | 9min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7528_HIS28-20266-6 | rígido | 9min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7530_HIS28-20266-8 | rígido | 1341min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7537_CMST-20266-2 | outros | 7min | (média 17, faixa 8.5-25.5) | ABAIXO | Thiago Oliveira |
| JULHO | 7570_LAP51-20266-6 | rígido | 21min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7571_LAP51-20266-7 | rígido | 21min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7572_LAP51-20266-8 | rígido | 21min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7573_LAP51-20266-9 | rígido | 22min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7574_LAP51-20266-10 | rígido | 22min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7575_LAP51-20266-11 | rígido | 22min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7576_LAP51-20266-12 | rígido | 22min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7578_LAP51-20266-14 | rígido | 23min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7579_LAP51-20266-15 | rígido | 23min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7580_LAP51-20266-16 | rígido | 17min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7581_LAP51-20266-17 | rígido | 17min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7582_LAP51-20266-18 | rígido | 17min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7583_LAP51-20266-19 | rígido | 16min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7584_LAP51-20266-20 | rígido | 18min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7585_LAP51-20266-21 | rígido | 18min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7586_LAP51-20266-22 | rígido | 18min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7587_LAP51-20266-23 | rígido | 18min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7588_LAP51-20266-24 | rígido | 19min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7589_LAP51-20266-25 | rígido | 19min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7601_LAP51-20266-26 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7602_LAP51-20266-27 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7603_LAP51-20266-28 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7604_LAP51-20266-29 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7605_LAP51-20266-30 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7606_LAP51-20266-31 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7607_LAP51-20266-32 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7608_LAP51-20266-33 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7609_LAP51-20266-34 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7611_ART11-20266-1 | rígido | 17min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7612_CIS28-20266-7 | rígido | 8min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7614_ART10-20266-1 | rígido | 19min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7615_LEDT-20266-11 | outros | 8min | (média 17, faixa 8.5-25.5) | ABAIXO | Bruno Mendes |
| JULHO | 7626_HIS28-20266-12 | rígido | 20min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7650_NAS20-20267-1 | rígido | 11min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7654_CM40T-20267-1 | outros | 31min | (média 17, faixa 8.5-25.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7659_LAP51-20267-1 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7660_LAP51-20267-2 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7661_LAP51-20267-3 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7662_LAP51-20267-4 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7663_LAP51-20267-5 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7664_LAP51-20267-6 | rígido | 12min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7665_LAP51-20267-7 | rígido | 8min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7666_LAP51-20267-8 | rígido | 9min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7667_LAP51-20267-9 | rígido | 10min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7668_LAP51-20267-10 | rígido | 11min | (média 5, faixa 2.5-7.5) | ACIMA | Thiago Oliveira |
| JULHO | 7669_LEDT-20267-6 | outros | 29min | (média 17, faixa 8.5-25.5) | ACIMA | Guilherme Silva |
| JULHO | 7670_LEDT-20267-7 | outros | 34min | (média 17, faixa 8.5-25.5) | ACIMA | Kaiky Nascimento |
| JULHO | 7671_LEDT-20267-8 | outros | 29min | (média 17, faixa 8.5-25.5) | ACIMA | Guilherme Silva |
| JULHO | 7711_CM27FC-20267-3 | outros | 8min | (média 17, faixa 8.5-25.5) | ABAIXO | Bruno Mendes |
| JULHO | 7718_HIS33-20267-1 | rígido | 10min | (média 5, faixa 2.5-7.5) | ACIMA | Guilherme Silva |
| JULHO | 7719_HIS33-20267-2 | rígido | 10min | (média 5, faixa 2.5-7.5) | ACIMA | Guilherme Silva |
| JULHO | 7720_HIS33-20267-3 | rígido | 10min | (média 5, faixa 2.5-7.5) | ACIMA | Guilherme Silva |
| JULHO | 7733_CMST-20267-1 | outros | 5min | (média 17, faixa 8.5-25.5) | ABAIXO | Guilherme Silva |
| JULHO | 7734_CMST-20267-2 | outros | 4min | (média 17, faixa 8.5-25.5) | ABAIXO | Guilherme Silva |
| JULHO | 7735_CMST-20267-3 | outros | 2min | (média 17, faixa 8.5-25.5) | ABAIXO | Guilherme Silva |
| JULHO | 7738_SC4KT-20267-5 | outros | 28min | (média 17, faixa 8.5-25.5) | ACIMA | André Afonso |
| JULHO | 7744_LAP51-20267-12 | rígido | 51min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7745_LAP51-20267-13 | rígido | 51min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7748_LAP51-20267-16 | rígido | 51min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7751_LAP51-20267-19 | rígido | 50min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7752_LAP51-20267-20 | rígido | 52min | (média 5, faixa 2.5-7.5) | ACIMA | André Afonso |
| JULHO | 7756_NAS10-20267-1 | rígido | 10min | (média 5, faixa 2.5-7.5) | ACIMA | Kaiky Nascimento |
