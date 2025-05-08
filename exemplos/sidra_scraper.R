# Exemplo de web scraping com o pacote rvest
# para ler tabelas do site do IBGE (SIDRA)
# O SIDRA é o Sistema IBGE de Recuperação Automática, que disponibiliza dados estatísticos

# Instala os pacotes necessários (caso não estejam instalados)
install.packages(c("rvest", "dplyr", "purrr", "janitor", "stringr"))

# Carrega os pacotes necessários
library(rvest)       # para fazer o scrap (leitura do HTML)
library(dplyr)       # operações de tidyverse
library(purrr)       # para iterar (map) de forma funcional
library(janitor)     # para limpar nomes de colunas
library(stringr)     # manipulações de strings, se necessário

fix_double_encoding <- function(txt) {
  # 1a etapa: ler como se fosse UTF-8 e transformar em Latin-1
  tmp <- iconv(txt, from = "UTF-8", to = "latin1", sub = "byte")
  # 2a etapa: agora ler como Latin-1 e converter para UTF-8 “definitivo”
  final <- iconv(tmp, from = "latin1", to = "UTF-8", sub = "byte")
  final
}

# URL alvo (conteúdo carregado pela página https://sidra.ibge.gov.br/home/pmc/brasil)
url <- "https://sidra.ibge.gov.br/ajax/home/pmc/1/brasil"

# Lê o conteúdo HTML da página
pagina <- read_html(url, encoding = "UTF-8")

# Identifica todos os nós <table> que tenham a classe usada pelo site 
# (no HTML, cada tabela está com class="quadro tabela-sidra")
tabelas_html <- pagina %>% html_nodes("table.quadro.tabela-sidra")

# Converte cada nó <table> para data.frame e depois tibble
lista_tabelas <- map(seq_along(tabelas_html), function(i) {
  
  # Extrai a i-ésima tabela como data.frame
  df <- tabelas_html[i] %>%
    html_table(fill = TRUE, dec = ",") %>%
    # html_table() retorna uma lista, geralmente com 1 data.frame
    purrr::pluck(1)
  
  # Ajusta nomes de colunas para evitar duplicados e caracteres especiais
  df <- df %>%
    clean_names()  # renomeia colunas (janitor)
  
  # Ajusta possíveis problemas de encoding, removendo caracteres inválidos
  df <- df %>%
    mutate(
      across(where(is.character), fix_double_encoding)
    )
  
  # Converte para tibble
  as_tibble(df)
})

# Dar nomes à lista de tabelas (opcional)
names(lista_tabelas) <- paste0("Tabela_", seq_along(lista_tabelas))

# Imprime cada tabela no console
for(i in seq_along(lista_tabelas)) {
  cat("===== ", names(lista_tabelas)[i], "=====\n")
  print(lista_tabelas[[i]])
  cat("\n")
}
