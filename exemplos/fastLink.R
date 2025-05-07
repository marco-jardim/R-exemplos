###############################################################################
# EXEMPLO DE PIPELINE TIDYVERSE  +  FASTLINK
# Autor : Marco Jardim (marcoeojardim@gmail.com)
# Objetivo : unir bases de cadastro 2020 e 2021 tratando typos / missing data
###############################################################################

## 0. CARREGAR PACOTES ---------------------------------------------------------
library(dplyr)      # mutate, select, joins (faz parte do tidyverse)
library(readr)      # read_csv
library(stringr)    # str_squish
library(janitor)    # clean_names
library(fastLink)   # linkage probabilístico
library(ggplot2)    # visualização
library(tibble)     # para as_tibble, tribble etc.
library(scales)       # para labels em %
library(utf8)      # para utf8::as_utf8 (não é necessário, mas é bom usar)

print("Fim do carregamento de pacotes\n")

## 1. LER E ARRUMAR DADOS ------------------------------------------------------
# -> read_csv() já converte datas automaticamente se formato ISO "YYYY-MM-DD"

base_a <- read_csv("./bases/cadastro_2020.csv",
              #     n_max = 20000,
                   show_col_types = FALSE) |>
  clean_names() |>                                   # id, primeiro_nome, ...
  mutate(across(where(is.character), str_squish)) |> # tira espaços duplicados
  mutate(ano = 2020)

base_b <- read_csv("./bases/cadastro_2021.csv",
               #    n_max = 20000,
                   show_col_types = FALSE) |>
  clean_names() |>
  mutate(across(where(is.character), str_squish)) |>
  mutate(ano = 2021)

print("Fim do carregamento de dados\n")

## 2. SELECIONAR VARIÁVEIS PARA LINKAGE ----------------------------------------
campos_link <- c("primeiro_nome", "sobrenome", "data_nasc", "sexo")

df_a <- base_a |>
  select(id_2020 = id, all_of(campos_link))

df_b <- base_b |>
  select(id_2021 = id, all_of(campos_link))

print("Fim da seleção de variáveis para linkage\n")

## 3. RODAR fastLink -----------------------------------------------------------
#  - stringdist.match: só para campos que precisam de distância (aqui nomes)
#  - cut.p (= p*) define o limiar de probabilidade para aceitar match.
#
link_out <- fastLink(
  dfA              = df_a,
  dfB              = df_b,
  varnames         = campos_link,
  stringdist.match = c("primeiro_nome", "sobrenome"), # Levenshtein default
  cut.a            = 0.94,    # limiar inferior (rarely used se cut.p domina)
  cut.p            = 0.85,    # p*: Pr(match)>=0.85 -> aceitar
  # n.cores          = parallel::detectCores() - 1, # todos os núcleos menos 1
  return.all       = TRUE, # devolve todas as probabilidades
)

# Depois de rodar fastLink (link_out) …
info <- summary(link_out)   # imprime e devolve lista invisível

print("Fim do linkage\n")

############################################################################
# 3a. Função auxiliar para FDR/FNR esperados
calc_fdr_fnr <- function(post, p_star = 0.85) {
  in_link <- post >= p_star
  tp_exp   <- sum(post[in_link], na.rm = TRUE)
  fp_exp   <- sum(1 - post[in_link], na.rm = TRUE)
  fn_exp   <- sum(post[!in_link], na.rm = TRUE)
  
  fdr <- fp_exp / (fp_exp + tp_exp)
  fnr <- fn_exp / (tp_exp + fn_exp)
  c(FDR = fdr, FNR = fnr)
}

# 3b. Aplique à coluna 'posterior' (probabilidades)
p_star <- 0.85
err <- calc_fdr_fnr(link_out$posterior, p_star)

fdr <- err["FDR"];
fnr <- err["FNR"]

cat(base::sprintf(
  "\n==== Qualidade do linkage ====\nFDR (False Discovery Rate): %.4f\nFNR (False Negative Rate): %.4f\n\n",
  fdr, fnr))

print("Fim do cálculo de FDR/FNR\n")

## 4. EXTRAIR TABELA DE MATCHES + PROBABILIDADE -------------------------------
# Veja args(getMatches); na versão CRAN  v0.6.0  3º arg = fl.out
matches_raw <- getMatches(
  dfA         = df_a,
  dfB         = df_b,
  fl.out      = link_out,
  threshold.match = 0.85,   # mesmo cut.p
  combine.dfs = TRUE        # ou FALSE se preferir só índices
)

matches_tbl <- as_tibble(matches_raw)
names(matches_tbl)          # <- agora apenas 1 argumento
#> [1] "id_2020" "dfB.match[, names.dfB]" "posterior"

matches <- matches_tbl |>
  rename(
    id_2021 = `dfB.match[, names.dfB]`,   # <- use backticks
    prob    = posterior          
  )

print("Fim da extração de matches\n")

## 5. JUNTAR MATCHES AOS DADOS ORIGINAIS --------------------------------------
dados_ligados <- matches |>
  # Junta registros 2020
  left_join(base_a |> rename(id_2020 = id), by = "id_2020") |>
  # Junta registros 2021
  left_join(base_b |> rename(id_2021 = id), by = "id_2021",
            suffix = c("_20", "_21"))

print("Fim da junção de dados\n")

## 6. ANÁLISE COM PESOS ξ (prob) ----------------------------------------------
resumo <- dados_ligados |>
  summarise(
    renda_media_ponderada = weighted.mean(renda_21, w = prob, na.rm = TRUE),
    matches_n             = n()
  )

print(resumo)

print("Fim do resumo ponderado\n")

###############################################################################
# FIM. O OBJETO 'dados_ligados' contém as duas linhas originais já unidas
#        + coluna 'prob' para usar
###############################################################################
