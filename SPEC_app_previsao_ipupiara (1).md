# App de previsão do tempo para Ipupiara-BA (Flutter)

## 1. Objetivo

App Flutter de uso pessoal que mostra a previsão do tempo de **Ipupiara-BA** com a maior precisão possível, combinando vários modelos meteorológicos da Open-Meteo. O app mostra uma "média" dos modelos, a probabilidade de chuva e um indicador de confiança. Não mostra apenas um número único.

- Localização fixa: Ipupiara-BA, lat **-11.82**, lon **-42.62** (aproximado; confirmar via API de geocodificação da Open-Meteo e deixar em uma constante).
- Fuso: `America/Bahia`. Idioma: pt-BR. Unidades: °C, mm, km/h.
- Horizonte: **hoje + próximos 7 dias**, todos com a mesma abordagem de cruzamento de modelos.
- Sem chave de API. Uso não comercial (plano gratuito da Open-Meteo). Mostrar a atribuição "Dados meteorológicos: Open-Meteo.com" na tela Sobre/rodapé.

## 2. Instruções iniciais para o agente

1. **Antes de codar**, chame as duas APIs abaixo com `curl` ou um script e inspecione o JSON real. Confirme os nomes das chaves (sufixos por modelo, nomes dos membros do ensemble, valores `null`). Não presuma, e ajuste este documento se algo divergir.
2. Mantenha a lógica de agregação em **Dart puro** (sem dependência de Flutter), com testes unitários.
3. Entregue por etapas (seção 9) e rode `flutter analyze` e `flutter test` ao fim de cada uma.

## 3. Fontes de dados

### 3.1 Previsão multimodelo (base da "média")
`GET https://api.open-meteo.com/v1/forecast`

Parâmetros:
- `latitude`, `longitude`, `timezone=America/Bahia`, `forecast_days=7`
- `models=ecmwf_ifs025,icon_seamless,gfs_seamless`
- `daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code`
- `hourly=temperature_2m,precipitation,weather_code` (para as próximas 24h)
- `current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m` (condição atual)

Com vários modelos, as chaves vêm com o nome do modelo como sufixo (ex.: `temperature_2m_max_ecmwf_ifs025`). **Valores `null` são esperados**, principalmente nos últimos dias, em que alguns modelos têm alcance menor. Ignore os modelos com `null` naquele dia e calcule com os que restarem.

### 3.2 Ensemble (probabilidade de chuva)
`GET https://ensemble-api.open-meteo.com/v1/ensemble`

- `models=ecmwf_ifs025,icon_seamless,gfs025`, `hourly=precipitation`, `forecast_days=7`, `timezone=America/Bahia` (**testado e funcionando**)
- **Formato real da resposta (confirmado):** os sufixos das chaves NÃO são iguais aos nomes pedidos em `models`:

  | Modelo pedido | Sufixo na resposta | Membros numerados | Controle |
  |---|---|---|---|
  | `ecmwf_ifs025` | `_ecmwf_ifs025_ensemble` | 50 | 1 |
  | `icon_seamless` | `_icon_seamless_eps` | 39 | 1 |
  | `gfs025` | `_ncep_gefs025` | 30 | 1 |

  - Membros: `precipitation_member01_<sufixo>`, `precipitation_member02_<sufixo>`, ...
  - **Controle:** a chave sem `memberNN` (ex.: `precipitation_ecmwf_ifs025_ensemble`) é a rodada de controle e **deve contar como um membro**. Total: 51 + 40 + 31 = **122 membros**.
  - **Não monte os nomes das chaves a partir do nome do modelo.** Faça o parse com regex (`^precipitation(_member\d+)?_(.+)$`) e agrupe pelo sufixo. Assim, se a API mudar um sufixo, o app não quebra.
  - ECMWF e GEFS repetem valores em blocos de 3 horas (a fonte é de 3 em 3 horas). Some as horas normalmente, mas confira o total diário contra o `precipitation_sum` da API de forecast para garantir que não está contando em dobro ou em triplo.
- **Agregação:** para cada membro, some a precipitação horária de cada dia local (`America/Bahia`). Depois conte quantos membros (todos os modelos juntos) passam do limiar de chuva. Limiar padrão: **≥ 1 mm/dia** (constante configurável).
- `probabilidadeChuva(dia) = membros com chuva ≥ limiar / total de membros`
- Calcule **também a probabilidade por modelo** e mostre na tela de detalhe do dia. Os modelos podem divergir muito (exemplo real de 10/11/2026: ECMWF ≈ todos os membros com chuva, ICON ≈ 25%, GEFS ≈ 94%).
- Observação: os membros do ECMWF têm garoa persistente de 0,1 mm/h, que soma facilmente 1 mm no dia. Isso pode inflar a probabilidade do ECMWF, então o limiar precisa ser fácil de ajustar (ex.: testar 2 mm).

### 3.3 Alertas do INMET (opcional, tolerante a falhas)
- Pesquisar a API pública de avisos do INMET (`apiprevmet3.inmet.gov.br`, verificar o endpoint de avisos ativos) e filtrar por Bahia / pelo código IBGE de Ipupiara.
- Mostrar como **faixa separada** na tela inicial ("Alerta do INMET: ..."). **Nunca entra na média.**
- Se a API falhar, estiver fora do ar ou mudar de formato, o app continua funcionando sem a faixa, sem erro visível.

### 3.4 Satélite e mapa (apenas exibição)
- Aba "Mapa" com `webview_flutter`, com duas seções: mapa do Windy (embed centrado em Ipupiara, overlay de chuva/nuvens) e imagem de satélite do CPTEC/INPE (verificar a URL atual das imagens GOES).
- Não há interpretação automática dessas imagens.

## 4. Regras de cálculo (domínio)

Para cada dia, a entrada é a lista de valores por modelo (podendo ter `null`).

| Variável | Valor exibido | Detalhe exibido |
|---|---|---|
| Temp. máxima e mínima | Média simples dos modelos disponíveis | Mín e máx entre modelos (faixa) |
| Chuva (mm) | Média dos modelos (opcionalmente a mediana dos membros do ensemble) | Faixa mín–máx e "N de M modelos preveem chuva (≥ 1 mm)" |
| Probabilidade de chuva | Do ensemble (seção 3.2) | — |
| Vento | Média da máxima | — |
| Ícone do tempo | `weather_code` mais frequente entre os modelos | Se a probabilidade de chuva for ≥ 60%, usar o ícone de chuva |

- Pesos: começar com **pesos iguais**, mas deixar uma constante `Map<String,double> pesosModelos` pronta para ajustar (por exemplo, dar mais peso ao ECMWF depois).
- Se o ensemble falhar, usar como fallback `modelosComChuva / modelosDisponíveis` e marcar a probabilidade como "estimativa".

### Indicador de confiança (por dia)
Calcule a partir da divergência entre os modelos e classifique em **Alta / Média / Baixa**:
- Temperatura: amplitude entre modelos (máx − mín) ≤ 2 °C → alta; ≤ 4 °C → média; acima disso → baixa.
- Chuva: se todos os modelos concordam (todos com ou todos sem chuva) → alta; se divergem → baixa. Probabilidade entre 30% e 70% rebaixa a confiança em um nível.
- A confiança final do dia é a **pior** das duas. Limiares ficam em constantes.
- Dias distantes (5 a 7) tendem a ter confiança menor naturalmente, e isso é esperado.

## 5. Telas

1. **Início (hoje)**
   - Condição atual, temperatura média da previsão de hoje (máx/mín), probabilidade de chuva e selo de confiança.
   - Gráfico ou lista das **próximas 24 h** (temperatura média e chuva).
   - Faixa de alerta do INMET, quando houver.
2. **Próximos 7 dias**
   - Lista com um cartão por dia: dia da semana e data, ícone, máx/mín (média), probabilidade de chuva, mm esperados, selo de confiança.
   - Tocar no dia abre o detalhe.
3. **Detalhe do dia**
   - Tabela **por modelo** (ECMWF, ICON, GFS): máx, mín, chuva, vento. O objetivo é o usuário ver onde os modelos concordam e onde divergem.
   - Resumo da agregação e explicação curta da confiança.
4. **Mapa** (Windy + satélite via WebView).
5. **Sobre / Configurações**
   - Atribuição Open-Meteo, hora da última atualização, botão de atualizar. (Local e limiar de chuva podem ficar fixos no MVP.)

## 6. Arquitetura sugerida

- Camadas: `data` (clientes HTTP, DTOs, cache) → `domain` (modelos, agregação, confiança) → `presentation` (telas, estado).
- Pacotes: `http` ou `dio`, `webview_flutter`, `shared_preferences` (cache), `intl` (pt-BR), `fl_chart` (opcional), gerenciamento de estado simples (Riverpod ou Provider).
- **Cache local** da última resposta bem-sucedida. Sem internet, mostrar os dados em cache com o aviso "atualizado em dd/mm HH:mm".
- Atualização automática ao abrir o app e com pull-to-refresh. Evitar nova chamada se o cache tiver menos de 30 minutos.
- Estados de tela: carregando, erro com botão "Tentar novamente", dados parciais (por exemplo, sem ensemble ou sem INMET).
- Tratar `null`, timeout (10 s) e respostas inesperadas sem derrubar o app. O parse deve ser defensivo.

## 7. Testes obrigatórios (domínio)

- Média de temperatura com 3 modelos e com 2 modelos (um `null`).
- Caso de chuva: modelos com 0, 0 e 20 mm → média ≈ 6,7 mm, "1 de 3 modelos preveem chuva", confiança baixa.
- Probabilidade do ensemble: 30 de 50 membros acima do limiar → 60%.
- Agregação horária para diária respeitando o fuso `America/Bahia` (cuidado com a virada de dia).
- Classificação de confiança nos limiares (2 °C, 4 °C, 30%, 70%).
- Fallback quando o ensemble falha.
- Parse das chaves do ensemble: agrupa por sufixo (`_ecmwf_ifs025_ensemble`, `_icon_seamless_eps`, `_ncep_gefs025`), inclui a rodada de controle e retorna 51, 40 e 31 membros respectivamente.

## 8. Fora de escopo (por enquanto)

Múltiplas cidades, notificações push, widgets, login, publicação em loja (a licença gratuita da Open-Meteo é não comercial), interpretação automática de imagem de satélite.

## 9. Etapas de implementação

1. Projeto Flutter, estrutura de pastas, constantes (local, modelos, limiares, pesos).
2. Clientes HTTP da Open-Meteo (forecast e ensemble) + DTOs + inspeção do JSON real.
3. Domínio: agregação, probabilidade, confiança + **testes**.
4. Tela "Início" e tela "7 dias" com dados reais.
5. Tela de detalhe por modelo.
6. Cache offline e tratamento de erros.
7. Aba Mapa (Windy + satélite).
8. Alertas do INMET (opcional, com fallback silencioso).
9. Polimento: tema claro/escuro, textos em pt-BR, tela Sobre com atribuição.

## 10. Critérios de aceite

- Mostra a previsão de hoje + 7 dias para Ipupiara, calculada pela combinação de ao menos 3 modelos.
- Cada dia mostra temperatura média, mm esperados, probabilidade de chuva e confiança.
- O detalhe mostra os valores individuais por modelo.
- O app funciona (com aviso) sem internet e sem os alertas do INMET.
- Testes de domínio passam e `flutter analyze` não tem erros.
