library('DT')
source('helpers.R')


# dats <- get_stringency_csv()
country_codes <- get_country_codes()

dat <- get_stringency_data(verbose = FALSE) %>% 
  left_join(
    country_codes, by = 'country_code'
  )

get_countries <- function(dat, continent) {
  unique(dat[dat$continent == continent, ]$country_name)
}

AFRICA <- get_countries(dat, 'Africa')
ASIA <- get_countries(dat, 'Asia')
EUROPE <- get_countries(dat, 'Europe')
EUROPE <- EUROPE[!is.na(EUROPE)] # remove one NA
OCEANIA <- get_countries(dat, 'Oceania')


OECD <- c(
  'Australia', 'Austria', 'Belgium', 'Canada', 'Chile', 'Colombia',
  'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 
  'Germany','Greece', 'Hungary', 'Iceland', 'Ireland', 'Israel',
  'Italy', 'Japan', 'South Korea', # 'Latvia', -> not in the database
  'Lithuania', 'Luxembourg', 'Mexico', 'Netherlands', 'New Zealand', 'Norway',
  'Poland', 'Portugal', 'Slovak Republic', 'Slovenia','Spain',  'Sweden',
  'Switzerland', 'Turkey', 'United Kingdom', 'United States'
)

NA_COUNTRIES <- c(
  'United States', 'Mexico', 'Canada', 'Guatemala',
  'Cuba', 'Haiti', 'Dominican Republic', 'Honduras',
  'El Salvador', 'Nicaragua', 'Costa Rica', 'Panama',
  'Puerto Rico', 'Jamaica', 'Trinidad & Tobago', 'Guadeloupe',
  'Martinique', 'Bahamas', 'Belize', 'Barbados', 'St. Lucia',
  'St. Vincent & Grenadines', 'U.S. Virgin Islands',
  'Antigua & Barbuda', 'Dominica', 'Bermuda', 'Greenland',
  'St. Kitts & Nevis','Turks & Caicos Islands','Saint Martin (French part)',
  'British Virgin Islands', 'Caribbean Netherlands',
  'Anguilla', 'St. Barthélemy', 'St. Pierre & Miquelon',
  'Montserrat'
)

NORTH_AMERICA <- c(
  'Barbados', 'Belize', 'Canada', 'Costa Rica', 'Cuba',
  'Dominica', 'Dominican Republic', 'El Salvador', 
  'Greenland', 'Guatemala', 'Honduras', 'Jamaica', 'Mexico',
  'Nicaragua', 'Panama', 'Trinidad and Tobago', 'United States'
)

SOUTH_AMERICA <- c(
  'Argentina', 'Aruba', 'Bermuda', 'Bolivia', 'Brazil',
  'Chile', 'Colombia', 'Ecuador', 'Guyana', 'Paraguay',
  'Peru', 'Puerto Rico', 'Suriname', 'Uruguay', 'Venezuela'
)

CUSTOM <- c(
  'Germany', 'Netherlands', 'Iran', 'Brazil',
  'United Kingdom', 'United States', 'Sweden', 'South Korea'
)

dat_us <- get_us_data()

continent_list <- case_when(
  country_codes$country_name %in% NA_COUNTRIES ~ 'North America',
  country_codes$continent == 'Americas' & !country_codes$country_name %in% NA_COUNTRIES ~ 'South America',
  TRUE ~ as.character(country_codes$continent)
)

MAPPING <- list(
  'Custom' = CUSTOM,
  'World' = dat$country_name %>% unique(),
  'Africa' = AFRICA,
  'North America' = NORTH_AMERICA,
  'South America' = SOUTH_AMERICA,
  'Asia' = ASIA,
  'Europe' = EUROPE,
  'Oceania' = OCEANIA,
  'OECD' = OECD
)


shinyServer(function(session, input, output) {
  
  ############################
  #### Code for the World Map
  ############################
  
  # Reactive Elements for the Map
  selected_mapdate <- reactive({ input$mapdate })
  selected_variable <- reactive({ input$variable_type })
  selected_measure <- reactive({ input$index_type })
  selected_region <- reactive({ input$region })
  
  # adjust selectInput options for USA and Stringency selections
  observe({
    region <- input$region
    var <- input$variable_type

    if (region == 'USA') {
      
      updateSelectInput(
        session, 'variable_type',
        choices = c(
          'Deaths' = 'Deaths',
          'Cases' = 'Cases'
          # 'Tests' = 'Tests'
          ), selected = selected_variable()
      )
      
    } else {
      
      updateSelectInput(
        session, 'variable_type',
        choices = c(
          'Stringency Index' = 'StringencyIndex',
          'Deaths' = 'Deaths',
          'Cases' = 'Cases'
          # 'Tests' = 'Tests'
        ), selected = selected_variable()
      )
      
    }

    if (var == 'StringencyIndex') {
      
      updateSelectInput(
        session, 'region',
        choices = c(
          'World' = 'World',
          'Europe' = 'Europe',
          'North America' = 'North America',
          'South America' = 'South America',
          'Asia' = 'Asia',
          'Africa' = 'Africa',
          'OECD' = 'OECD'),
        selected = selected_region()
      )
      
    } else {
      
      updateSelectInput(
        session, 'region',
        choices = c(
          'World' = 'World',
          'Europe' = 'Europe',
          'North America' = 'North America',
          'South America' = 'South America',
          'Asia' = 'Asia',
          'Africa' = 'Africa',
          'OECD' = 'OECD',
          'USA (States)' = 'USA'
        ), selected = selected_region()
      )
      
    }
  })
  
  output$heatmap <- renderPlotly({
    p <- plot_world_data(
      dat, selected_mapdate(), selected_variable(),
      selected_measure(), selected_region(), dat_us
    )
    p
  })
  
  #######################################
  #### Code for Individual Country Figure
  #######################################
  
  observeEvent(input$regions, {
    region <- input$regions
    country_choices <- MAPPING[[region]]
    country_selected <- MAPPING[[region]]
    
    if (region == 'Custom') {
      country_choices <- MAPPING[['World']]
    }
    
    updateSelectInput(
      session, 'countries_lockdown',
      choices = country_choices, selected = country_selected
    )
  })

  observeEvent(input$clear_graph, {
    updateSelectInput(session, 'countries_lockdown', selected = '')
  })
  
  observeEvent(input$all_graph, {
    updateSelectInput(session, 'countries_lockdown', selected = unique(dat$country_name))
  })
  
  country_list <- reactive({
      input$countries_lockdown
  })
  
  selected_countries <- reactive({ 
    input$refresh
    isolate(country_list())
  })
  
  observe({
    # Do not allow user to click 'Apply' when selection is empty
    toggleState(
      'refresh', condition = length(input$countries_lockdown) != 0
    )
  })
  
  num_cols <- reactive({
    len <- length(selected_countries())
    ifelse(len > 10, 5, ifelse(len > 4, 4, len))
  })
  
  
  selected_plot <- reactive({
    
    if (input$graph == 'New Deaths per Million') {
      
      p <- plot_stringency_data_deaths_relative(
        dat, selected_countries(), num_cols()
      )
    
    } else if (input$graph == 'New Cases per Million') {
      
      p <- plot_stringency_data_cases_relative(
        dat, selected_countries(), num_cols()
      )
      
    } else {
      p <- plot_stringency_data_tests(
        dat, selected_countries(), num_cols()
      )
    }
    
    p
  })
  
  how_high <- reactive({
    len <- length(selected_countries())
    (((len - 1) %/% num_cols()) + 1) * 200
  })
  
  output$lockdown_plot_lines_scales <- renderPlot({
    input$refresh
    isolate(selected_plot())
  }, height = how_high)
  
  
  #######################
  #### Code for the Table
  #######################
  
  # Reactive Elements for the Table
  selected_countries_table <- eventReactive(
    input$TableApply, { input$countries_table },
    ignoreNULL = FALSE
  )

  observeEvent(input$TableClear, {
    updateSelectInput(session, 'countries_table', selected = '')
  })
  
  observeEvent(input$TableAll,{
    updateSelectInput(session, 'countries_table', selected = unique(dat$country_name))
  })
  
  observeEvent(input$continent_table, {
    region <- input$continent_table
    country_choices <- MAPPING[[region]]
    country_selected <- MAPPING[[region]]
    
    if (region == 'Custom') {
      country_choices <- MAPPING[['World']]
    }
    
    updateSelectInput(
      session, 'countries_table',
      choices = country_choices, selected = country_selected
    )
  })
  
  observe({
    # Do not allow user to click 'Apply' when selection is empty
    toggleState(
      'TableApply', condition = length(input$countries_table) != 0
    )
  })
  
  output$table_legend <- renderPlot({
    swatchplot(
      sequential_hcl(
        n = 10, h = c(250, 90), c = c(40, NA, 22),
        l = c(68, 100), power = c(3, 3), rev = TRUE
      ), font = 3, cex = 0.9, line = 3
    )
    
    mtext('Not \n Ready', side = 2, las = 2, line = 1, cex = 1.25, outer = FALSE, adj = 0.5)
    mtext('How ready are countries to lift the Lockdown?', side = 3, line = 1, cex = 1.5, outer = FALSE)
    mtext('Ready', side = 4, las = 2, line = 1, cex = 1.25, outer = FALSE, adj = 0.65)
  })
  
  output$countries_table <- DT::renderDT({
    rowCallback <- c(
      'function(row, data){',
      '  for(var i=2; i<data.length; i++){',
      '    if(data[i] === null){',
      "      $('td:eq('+i+')', row).html('Data Not Available')",
      "        .css({'color': 'rgb(0,0,0)', 'font-style': 'italic'});",
      '    } else if(data[i] < 0){',
      "      $('td:eq('+i+')', row).html('Lifted '+ Math.abs(data[i]) + ' Days Ago')",
      "        .css({'font-style': 'normal'});",
      '    } else if(data[i] === 0){',
      "      $('td:eq('+i+')', row).html('Not Implemented')",
      "        .css({'color': 'rgb(0,0,0)', 'font-style': 'italic'});",
      '}',
      '}',
      '}'
    )

    tab <- prepare_country_table(dat, selected_countries_table())
    tab <- datatable(
      tab, options = list(
        columnDefs = list(list(targets = 10, visible = FALSE)), rowCallback = JS(rowCallback),
        pageLength = 25
        # columnDefs = list(list(targets = 10:17, visible = FALSE)), rowCallback = JS(rowCallback)
        )
      ) %>%
      formatString(2:9, 'In Place for ',' Days') %>%
      formatStyle(
        'roll', target = 'row',
        backgroundColor = styleInterval(
          c(0.5,0.6,0.7,0.8,0.9,0.95,0.99),
          sequential_hcl(
            n = 8, h = c(250, 90), c = c(40, NA, 22), l = c(68, 100), power = c(3, 3), rev = TRUE#, register =
          )
        )
      )
    
    tab
  })
    
    # TODO: add this when we have the flag variable for the stringency index!
      # formatStyle(
      #   'Mandatory school closing', valueColumns = 'school_closing_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Mandatory workplace closing',
      #   valueColumns = 'workplace_closing_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Mandatory cancellation of public events',
      #   valueColumns = 'cancel_events_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Mandatory public transport closing',
      #   valueColumns = 'transport_closing_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Gatherings restricted below 100 people',
      #   valueColumns = 'gatherings_restrictions_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Leaving home restricted by law (with minimal exceptions)',
      #   valueColumns = 'internal_movement_restrictions_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # ) %>%
      # formatStyle(
      #   'Mandatory restrictions of internal transport',
      #   valueColumns = 'international_movement_restrictions_flag',
      #   fontWeight = styleEqual(1, 'bold')
      # )
})