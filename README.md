# Record Linkage com **fastLink** + tidyverse

---

## Visão geral

> **Objetivo** Ligar (fazer *record linkage*) dois cadastros simulados — ano 2020 e 2021 — mesmo contendo grafias diferentes, erros de digitação, campos faltantes etc.
> Usamos o pacote **fastLink** (R) para calcular, de forma probabilística, quais registros se referem à mesma pessoa e mensurar a incerteza (FDR/FNR).

---

## Estrutura de pastas

```text
projeto/
├── bases/            # CSVs gerados pelo gerador.py  (cadastro_2020.csv, cadastro_2021.csv)
├── exemplos/
│   ├── fastLink.R    # script principal de linkage  ← você vai editar/rodar
│   └── fastLink.setup.R   # instala os pacotes de que o script depende
└── utils/
    └── gerador.py    # programa Python que cria bases sintéticas
```

---

## 1. Pré-requisitos

| Software               | Versão mínima                  | Para que serve               |
| ---------------------- | ------------------------------ | ---------------------------- |
| **R**                  | 4.2 +                          | ambiente de análise          |
| **RStudio** (opcional) | 2023 +                         | IDE amigável                 |
| **Python**             | 3.9 +                          | só para gerar dados de teste |
| Compilador C++         | g++, clang ou Rtools (Windows) | compilar fastLink            |

> Se estiver em laboratório da faculdade, R/RStudio já devem estar instalados; peça aos monitores para acrescentar o pacote C++ se faltar.

---

## 2. Instalar pacotes R (apenas 1 ª vez)

Abra o *Console* do R ou o *RStudio* e rode:

```r
source("exemplos/fastLink.setup.R")   # instala tidyverse, janitor, fastLink, scales, utf8
```

Esse passo baixa e compila tudo; pode demorar uns minutos.

---

## 3. Gerar bases de exemplo

Dentro da pasta `projeto/`:

```bash
# Linux / macOS
python utils/gerador.py
# Windows (no PowerShell ou Prompt)
python utils\gerador.py
```

O script cria:

* `bases/cadastro_2020.csv`   (30 000 linhas)
* `bases/cadastro_2021.csv`   (\~36 000 linhas, com 6 000 clones alterados)

---

## 4. Executar o pipeline de linkage

No R/RStudio:

```r
source("exemplos/fastLink.R", encoding = "UTF-8")
```

Você verá no **Console**:

```
==== Qualidade do linkage ====
FDR (False Discovery Rate): 0.0092
FNR (False Negative Rate): 0.1117
# A tibble: 1 × 2
  renda_media_ponderada matches_n
                9139.0      5322
```

* **FDR** ≈ 0,9 % → < 1 % dos pares aceitos são falsos-positivos.
* **FNR** ≈ 11 % → 11 % dos pares verdadeiros ficaram de fora.
* **renda\_media\_ponderada** → média de `renda_2021` ponderada pela probabilidade de match.

Um gráfico de barras será exibido mostrando FDR × FNR.

---

## 5. Lendo apenas *N* linhas para testes rápidos

Em `fastLink.R` comente ou descomente o parâmetro **`n_max`**:

```r
base_a <- read_csv("./bases/cadastro_2020.csv",
                   n_max = 1000,          # ← lê só 1 000 primeiras linhas
                   show_col_types = FALSE)
```

Use isso quando quiser validar o código sem esperar pelo conjunto completo.

---

## 6. Arquivos de saída importantes

| Objeto em memória | O que contém                                             | Como usar                        |
| ----------------- | -------------------------------------------------------- | -------------------------------- |
| `link_out`        | resultados brutos do fastLink (pesos, pós-probabilidade) | diagnóstico avançado             |
| `matches`         | tibble **id\_2020, id\_2021, prob**                      | pares ligados + probabilidade    |
| `dados_ligados`   | registros das duas bases já unidos                       | análises subsequentes            |
| `resumo`          | média ponderada da renda + nº de matches                 | exemplo de estatística ponderada |

Salve se quiser reutilizar:

```r
write_csv(matches, "bases/matches.csv")
saveRDS(link_out, "bases/link_out.rds")
```

---

## 7. Erros comuns e soluções

| Mensagem                                   | Causa                        | Solução                                             |
| ------------------------------------------ | ---------------------------- | --------------------------------------------------- |
| `No matches found for the threshold value` | Overlap baixo ou limiar alto | Diminua `cut.p` (ex.: 0.7) **ou** aumente `n_max`.  |
| `Can't rename columns that don't exist`    | Coluna `posterior` sumiu     | Confira `names(matches_tbl)` e ajuste o `rename()`. |
| `package 'utf8' not found`                 | dependência faltante         | `install.packages("utf8")`                          |
| Gráfico não aparece                        | script rodado via `source()` | finalize com `print(meu_grafico)` ou use `RStudio`. |

---

## 8. Próximos passos

1. **Experimente outras chaves** — adicione `uf`, `municipio`, etc.
2. **Indexação (*blocking*)** — reduza o tempo criando blocos com `surname_soundex`.
3. **Propague a incerteza** — use `prob` como peso em regressões (`glm(..., weights = prob)`).
4. **Compare com método determinístico** — faça `inner_join()` por nome + data\_nasc e compare FDR/FNR.

---

## 9. Exemplo: Crawler de dados do SIDRA (Pesquisa Mensal de Comércio)

Este exemplo demonstra como **raspar dados** (scraping) diretamente do site do IBGE/SIDRA referente à **Pesquisa Mensal de Comércio (PMC)**. O script localiza as tabelas em HTML, converte para data frames (ou *tibbles*) e aplica correções de nomes/encoding.

### 9.1. Estrutura e Objetivo do Script

O arquivo `sidra_scraper.R` contém um conjunto de etapas para realizar a captura de tabelas e a correção de possíveis problemas de *encoding*. Essas tabelas são exibidas na página do SIDRA em formato HTML e se encontram na seção da **Pesquisa Mensal de Comércio**.

1. **Leitura da página**  
   O script utiliza a função `read_html()` do pacote **rvest** para carregar o conteúdo HTML. O URL apontado (`https://sidra.ibge.gov.br/ajax/home/pmc/1/brasil`) retorna uma versão em HTML contendo as tabelas que vemos no *dashboard* da PMC.

2. **Seleção de Tabelas**  
   Em seguida, localizamos todas as tags `<table>` que possuam as classes `"quadro tabela-sidra"`. No código, isso se dá pelo seletor CSS:
   ```r
   tabelas_html <- pagina %>% html_nodes("table.quadro.tabela-sidra")
   ```

Cada *table* corresponde a um bloco de dados exibido na página.

3. **Conversão para Data Frames/Tibbles**
   Para cada tabela coletada, o script chama `html_table(fill = TRUE, dec = ",")`. Isso retorna uma lista de data frames. Frequentemente, cada tabela só contém um data frame, então usamos `pluck(1)` para extrair.
   Após isso, aplicamos o `janitor::clean_names()` para garantir que nomes de colunas sejam padronizados (sem espaços, caracteres especiais, etc.).

4. **Correção de Encoding**
   Frequentemente, páginas em português podem apresentar caracteres acentuados corrompidos. Para corrigir, o script define a função `fix_double_encoding()`. Esta função faz uma “conversão dupla” via `iconv()`, resolvendo casos de sobreposição de encoding (“ComÃ©rcio” → “Comércio”).
   Em seguida, através de `mutate(across(where(is.character), fix_double_encoding))`, garantimos que todos os campos de texto sejam tratados.

5. **Armazenamento e Impressão**
   As tabelas resultantes são armazenadas em uma `lista_tabelas`, cada qual convertida em um tibble. Por fim, o script imprime cada tabela no console.
   Se quiser salvar em disco, basta adaptar o código para `write_csv(lista_tabelas[[i]], "nome_arquivo.csv")` ou algo equivalente.

### 9.2. Localização do Script

No diretório `./exemplos/`, encontramos:

```
exemplos/
├── fastLink.R
├── fastLink.setup.R
└── sidra_scraper.R   # Script principal de scraping do SIDRA
```

### 9.3. Dependências

| Pacote      | Função                           |
| ----------- | -------------------------------- |
| **rvest**   | Leitura de páginas HTML          |
| **dplyr**   | Manipulação de dados (tidyverse) |
| **purrr**   | Iterações funcionais (`map()`)   |
| **janitor** | Limpeza de nomes de colunas      |
| **stringr** | Manipulações de strings          |

### 9.4. Como Executar

1. **Instalar pacotes** (caso ainda não estejam disponíveis):

   ```r
   install.packages(c("rvest", "dplyr", "purrr", "janitor", "stringr"))
   ```

2. **Executar** o script:

   ```r
   source("exemplos/sidra_scraper.R", encoding = "UTF-8")
   ```

   Você verá o conteúdo de cada tabela aparecendo no console sob o nome `Tabela_1`, `Tabela_2`, etc.

### 9.5. Observações e Personalizações

* **Mudança de URL**: Se o IBGE alterar o endpoint do SIDRA ou a estrutura HTML, você deverá atualizar a variável `url` ou o seletor de classes (`"table.quadro.tabela-sidra"`).
* **Salvar em Arquivos**: Para persistir os dados, você pode substituir o `print()` no final por `write_csv()`, salvando cada tibble em um `.csv`.
* **Uso de Encoding**: Caso apareçam caracteres quebrados ou “�”, teste alternar `from="latin1"` e `to="UTF-8"` ou vice-versa dentro do `iconv()`.
* **Automatização**: Pode-se agendar o script para rodar periodicamente (usando CRON no Linux, ou Tarefas Agendadas no Windows), automatizando a coleta de dados.

---

