library(shinydashboard)
library(DT)
library(shiny)
library(httr)
httr::set_config(httr::config(http_version = 0))
library(xml2)
library(RPostgreSQL)
library(DBI)
library(stringr)
library(plotly)
library(dplyr)
library(HGNChelper)

showabstracttable <- function(pmids) {
  data("hgnc.table", package="HGNChelper")
  incProgress(amount = 0.5, detail = paste("Retrieving Abstracts and Building Table"))
  con <- RPostgreSQL::dbConnect(DBI::dbDriver("PostgreSQL"), dbname = "nolelin",host = "localhost",port = 5432,user = "nolelin")
  res <- dbGetQuery(con, sprintf("select pmid, unnest(genes) as genes from pubmed_genes where pmid in (%s) and cardinality(genes) > 0 limit 5000", paste(pmids, collapse=",")))
  res <- res %>% filter(genes %in% hgnc.table$Approved.Symbol | genes %in% hgnc.table$Symbol)
  res2 <- dbGetQuery(con, sprintf("select pmid, abstracttext, title from pubmed_datasource where pmid in (%s)", paste(res$pmid, collapse=",")))
  RPostgreSQL::dbDisconnect(con)
  if (is.null(res2)) {
    return(setNames(data.frame(matrix(ncol = 3, nrow = 0)), c("abstracts", "genes", "pmid")))
  }
  df <- res2 %>% inner_join(res)
  df2 <- df %>% group_by(pmid, abstracttext, title) %>% summarize(genelist = strsplit(paste(sort(unique(genes)),collapse=","), ","))
  abstract_txt <- df2$abstracttext
  gene_list <- df2$genelist
  title_txt <- df2$title
  pmid_list <- df2$pmid
  abstract_txt_list <- c()
  gene_txt_list <- c()
  pmid_txt_list <- c()
  for (i in 1:length(abstract_txt)) {
    str_locations <- str_locate_all(abstract_txt[i], gene_list[[i]])
    for (j in 1:(length(str_locations[[1]])/2)) {
      abstract_txt_list <- c(abstract_txt_list, substr(abstract_txt[i], str_locations[[1]][j,][[1]] - 50, str_locations[[1]][j,][[2]] + 50))
      gene_txt_list <- c(gene_txt_list, substr(abstract_txt[i], str_locations[[1]][j,][[1]], str_locations[[1]][j,][[2]]))
      pmid_txt_list <- c(pmid_txt_list, pmid_list[i])
    }
  }
  df <- data.frame(abstract_txt_list, gene_txt_list, pmid_txt_list)
  names(df) <- c("abstracts", "genes", "pmid")
  incProgress(amount = 0.5, detail = paste("Got Abstracts and Built Table"))
  return(df)
}

getgenespsql <- function(pmids) {
  incProgress(amount = 0.5, detail = paste("Retrieving PMIDs"))
  con <- RPostgreSQL::dbConnect(DBI::dbDriver("PostgreSQL"), dbname = "nolelin",host = "localhost",port = 5432,user = "nolelin")
  res <- dbGetQuery(con, sprintf("select unnest(genes) as genes from pubmed_genes where pmid in (%s) and cardinality(genes) > 0 limit 5000", paste(pmids, collapse=",")))
  RPostgreSQL::dbDisconnect(con)
  incProgress(amount = 0.5, detail = paste("Got PMIDs"))
  return(res)
}

getncbiquery <- function(query) {
  if (query == "") {
    incProgress(amount = 1, detail = paste("Nothing entered"))
    return(list("0"))
  } else {
    incProgress(amount = 1, detail = sprintf("Looking up %s", query))
  }
  url <- sprintf("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=%s&retmode=json&retmax=50000&mindate=1995&maxdate=2020", query)
  url <- URLencode(url)
  response <- GET(url)
  rescon <- content(response, "parsed")
  return(rescon$esearchresult$idlist)
}

getcounts <- function(genes) {
  if (dim(genes)[1] > 0) {
    data("hgnc.table", package="HGNChelper")
    genes %>% group_by(genes) %>% summarize(count=n()) %>% filter(genes %in% hgnc.table$Approved.Symbol | genes %in% hgnc.table$Symbol)
  } else {
    setNames(data.frame(matrix(ncol = 2, nrow = 0)), c("genes", "count"))
  }
}

server <- function(input, output) {
  finalvalue <- eventReactive(input$submit, {
    withProgress(message = "Running Query",
                 value = 0, {
                   getncbiquery(input$user_text)
                 })
  })
  
  geneTable <- reactive({
    finalvalue <- finalvalue()
    if (length(finalvalue) > 0) {
      withProgress(message = 'Getting PMIDs',
                   value = 0, {
                     genes <- getgenespsql(finalvalue)
                   })
      withProgress(message = 'Building Bar Graph',
                   value = 0, {
                     df <- getcounts(genes)
                   })
      if(dim(df)[1] > 0) {
        df$genes <- factor(df$genes,df$genes[order(-df$count)])
      }
    }
    df
  })
  output$plotlyBar <- renderPlotly({
    df <- geneTable()
    if (dim(df)[1] > 0) {
      plot_ly(
        x=df$genes,
        y=df$count,
        name="Gene Counts",
        type="bar",
        width=max(300, 40 * nrow(df))
      )
      } else {
        plot_ly(
          x=c(""),
          y=c(0),
          name="Gene Counts",
          type="bar"
        )
      }
  })

  output$x1 <- renderDataTable({
    final_value <- finalvalue()
    if (length(final_value) > 0) {
      withProgress(message = 'Getting Abstracts and Genes',
                   value = 0, {
                     table1 <- showabstracttable(final_value)
                   })
      table1 <- table1 %>% mutate(pmid = sprintf("<a href='https://www.ncbi.nlm.nih.gov/pubmed/%s'>%s</a>",pmid, pmid))
      DT::datatable(table1, options = list(pageLength = 25, columnDefs = list(list(targets=c(0,2), searchable = FALSE))), rownames = FALSE, escape = FALSE)
    } else {
      DT::datatable(setNames(data.frame(matrix(ncol = 3, nrow = 0)), c("abstracts", "genes", "pmid")), options = list())
    }
  })
}