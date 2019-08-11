## app.R ##
library(shinydashboard)
library(shiny)
library(plotly)
library(DT)

jscode <- '
$(function() {
var $els = $("[data-proxy-click]");
$.each(
$els,
function(idx, el) {
var $el = $(el);
var $proxy = $("#" + $el.data("proxyClick"));
$el.keydown(function (e) {
if (e.keyCode == 13) {
$proxy.click();
}
});
}
);
});
'

dt_output = function(title, id) {
  fluidRow(column(
    12, h1(paste0(title)),
    hr(), DTOutput(id)
  ))
}

ui <- dashboardPage(
  dashboardHeader(title = "Genetic Streetlight"),
  dashboardSidebar(
    tags$head(tags$script(HTML(jscode))),
    # input field
    tagAppendAttributes(
      textInput("user_text", label = "Enter medical term:", placeholder = "Please enter some text."),
      `data-proxy-click` = "submit"
    ),
    
    # submit button
    actionButton("submit", label = "Submit")
    
  ),
  dashboardBody(
    fluidRow(box(div(plotlyOutput("plotlyBar", width = "1000px"), style = "overflow-x: scroll"),width=12),
             
             box(dataTableOutput('x1'), width=12))
  )
)


