# clean environment
remove(list = ls())
# required packages
library(ggplot2)
library(ggrepel)
library(zoo)
library(lme4)
library(dplyr)
library(scales)
library(ggpubr)
library(grid)
library(gridExtra)

# import Sciensano hospitalisations data
dat <- read.csv("https://epistat.sciensano.be/Data/COVID19BE_HOSP.csv")

## Recoding dat$PROVINCE
dat$PROVINCE <- recode_factor(dat$PROVINCE,
                              "Brussels" = "Brabant",
                              "VlaamsBrabant" = "Brabant",
                              "BrabantWallon" = "Brabant"
)

# aggregate new intakes by province and date
dat <- aggregate(NEW_IN ~ DATE + PROVINCE, dat, sum)

# add new intakes for Belgium as a whole
belgium <- aggregate(NEW_IN ~ DATE, dat, sum)
belgium$PROVINCE <- "Belgium"
col_order <- c("DATE", "PROVINCE", "NEW_IN")
belgium <- belgium[, col_order]
dat <- rbind(dat, belgium)

# transform date and provinces
dat$DATE <- as.Date(dat$DATE)
dat$PROVINCE <- factor(dat$PROVINCE,
  levels = c(
    "Brabant",
    "Antwerpen",
    "Hainaut",
    "Limburg",
    "Liège",
    "Luxembourg",
    "Namur",
    "OostVlaanderen",
    "WestVlaanderen",
    "Belgium"
  ),
  labels = c(
    "Brabant",
    "Antwerpen",
    "Hainaut",
    "Limburg",
    "Liège",
    "Luxembourg",
    "Namur",
    "Oost-Vlaanderen",
    "West-Vlaanderen",
    "Belgium"
  )
)

# compute NEW_IN by population size
dat <- dat %>%
  mutate(population = case_when(
    PROVINCE == "Antwerpen" ~ 1857986,
    PROVINCE == "Brabant" ~ 2758316,
    PROVINCE == "Hainaut" ~ 1344241,
    PROVINCE == "Liège" ~ 1106992,
    PROVINCE == "Limburg" ~ 874048,
    PROVINCE == "Luxembourg" ~ 284638,
    PROVINCE == "Namur" ~ 494325,
    PROVINCE == "Oost-Vlaanderen" ~ 1515064,
    PROVINCE == "West-Vlaanderen" ~ 1195796,
    PROVINCE == "Belgium" ~ 11431406
  )) %>%
  mutate(NEW_IN_divid = NEW_IN / population * 100000)


# Create plot in english
fig_trends <- ggplot(
  subset(dat, DATE >= "2020-06-21" & PROVINCE != "Belgium"),
  aes(x = DATE, y = NEW_IN_divid)
) +
  geom_point(
    size = 1L,
    colour = "steelblue"
  ) +
  labs(x = "", y = "Number of hospitalisations (per 100,00 inhabitants)") +
  theme_minimal() +
  facet_wrap(vars(PROVINCE),
             scales = "free"
  ) +
  geom_smooth(
    se = FALSE,
    col = "grey",
    method = "gam",
    formula = y ~ s(x)
  ) +
  geom_vline(
    xintercept = as.Date("2020-07-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  geom_vline(
    xintercept = as.Date("2020-08-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  geom_vline(
    xintercept = as.Date("2020-09-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  labs(
    title = " "
  ) +
  scale_y_continuous(breaks = seq(from = 0, to = 1.5, by = 1), limits = c(0, 1.5)) +
  scale_x_date(labels = date_format("%d-%m"))

# Create plot in english
fig_trends_bel <- ggplot(
  subset(dat, DATE >= "2020-06-21" & PROVINCE == "Belgium"),
  aes(x = DATE, y = NEW_IN_divid)
) +
  geom_point(
    size = 1L,
    colour = "steelblue"
  ) +
  labs(x = "", y = "") +
  theme_minimal() +
  facet_wrap(vars(PROVINCE),
             scales = "free"
  ) +
  geom_smooth(
    se = FALSE,
    col = "grey",
    method = "gam",
    formula = y ~ s(x)
  ) +
  geom_vline(
    xintercept = as.Date("2020-07-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  geom_vline(
    xintercept = as.Date("2020-08-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  geom_vline(
    xintercept = as.Date("2020-09-01"), linetype = "dashed",
    color = "lightgrey", size = 0.5
  ) +
  labs(
    title = "Evolution of hospital admissions - COVID-19"
  ) +
  scale_y_continuous(breaks = seq(from = 0, to = 1.5, by = 1), limits = c(0, 1.5)) +
  scale_x_date(labels = date_format("%d-%m")) +
  theme(panel.border = element_rect(colour = "steelblue", fill = NA, size = 3))

## adjust caption at the end of the trend figure
caption <- grobTree(
  textGrob("* Solid lines: curves fitted to observations",
           x = 0, hjust = 0, vjust = 0,
           gp = gpar(col = "darkgray", fontsize = 7, lineheight = 1.2)
  ),
  textGrob("Niko Speybroeck (@NikoSpeybroeck), Antoine Soetewey (@statsandr) & Angel Rosas (@arosas_aguirre) \n Data: https://epistat.wiv-isp.be/covid/  ",
           x = 1, hjust = 1, vjust = 0,
           gp = gpar(col = "black", fontsize = 7.5, lineheight = 1.2)
  ),
  cl = "ann"
)


##### MAPS

### Obtaining Belgium shapefile at province level

library(GADMTools)
library(RColorBrewer)
library(tmap)

## sf structure
map <- gadm_sf_loadCountries(c("BEL"), level = 2, basefile = "./")$sf
map <- map %>%
  rename("PROVINCE" = NAME_2)

map$PROVINCE[c(1, 5)] <- c("Brussels", "Vlaams-Brabant")

## agregating data
dat_ag <- dat %>%
  group_by(PROVINCE) %>%
  summarize(
    "new_in" = sum(NEW_IN, na.rm = T),
    "new_in2" = sum(NEW_IN[DATE >= "2020-05-04"], na.rm = T),
    "population" = max(population, na.rm = T)
  ) %>%
  mutate(
    new_in_divid = new_in / population * 100000,
    new_in_divid2 = new_in2 / population * 100000
  )

map.data <- left_join(map, dat_ag, by = "PROVINCE")
map.data <- subset(map.data, !PROVINCE %in% "Belgium")

###### MAPS WITH GGPLOT

points <- st_centroid(map.data)
points <- cbind(map.data, st_coordinates(st_centroid(map.data$geometry)))

points <- mutate(points,
  num_1 = paste("(", round(new_in_divid, 1), ")"),
  num_2 = paste("(", round(new_in_divid2, 1), ")"),
  q1 = as.numeric(cut(new_in_divid,
    breaks = quantile(new_in_divid, probs = seq(0, 1, by = 0.25), na.rm = TRUE),
    include.lowest = TRUE
  )),
  q2 = as.numeric(cut(new_in_divid2,
    breaks = quantile(new_in_divid2, probs = seq(0, 1, by = 0.25), na.rm = TRUE),
    include.lowest = TRUE
  )),
  q1 = as.factor(ifelse(q1 < 4, 1, 2)),
  q2 = as.factor(ifelse(q2 < 4, 1, 2))
)

points1 <- subset(points, !PROVINCE %in% "Vlaams-Brabant")
points2 <- subset(points, PROVINCE %in% "Vlaams-Brabant")

period1 <- paste0("Période / periode : 15/03 - ", format(Sys.Date() - 1, format = "%d/%m"), "   ")
period2 <- paste0("Période / periode : 04/05 - ", format(Sys.Date() - 1, format = "%d/%m"), "   ")



fig_map1 <- ggplot(map.data) +
  geom_sf(aes(fill = new_in_divid)) +
  # here you can change the number of blues in the pallete "n" (maximum=9)
  scale_fill_gradientn(colors = brewer.pal(n = 9, name = "Blues")) +
  geom_text(
    data = points1, aes(x = X, y = Y + 0.03, label = PROVINCE, colour = q1), size = 3,
    check_overlap = TRUE
  ) +
  scale_colour_manual(values = c("black", "white"), guide = FALSE) +
  geom_text(
    data = points1, aes(x = X, y = Y - 0.03, label = num_1, colour = q1), size = 3,
    check_overlap = TRUE
  ) +
  geom_text(
    data = points2, aes(x = X + 0.07, y = Y + 0.09, label = PROVINCE), col = "black", size = 3,
    check_overlap = TRUE
  ) +
  geom_text(
    data = points2, aes(x = X + 0.07, y = Y + 0.03, label = num_1), col = "black", size = 3,
    check_overlap = TRUE
  ) +
  labs(fill = bquote(atop(NA, atop("Admissions hospitalières / \nHospitalisaties (x 100,000 hab./inw.)", bold(.(period1)))))) +
  theme_void() +
  theme(
    # Change legend
    legend.position = c(0.2, 0.22),
    legend.title = element_text(size = 12, color = "black"),
    legend.text = element_text(color = "black"),
    plot.margin = unit(c(+0.2, 0, -0.5, 3), "cm")
  )


fig_map2 <- ggplot(map.data) +
  geom_sf(aes(fill = new_in_divid2)) +
  # here you can change the number of blues in the pallete "n" (maximum=9)
  scale_fill_gradientn(colors = brewer.pal(n = 9, name = "Blues")) +
  geom_text(
    data = points1, aes(x = X, y = Y + 0.03, label = PROVINCE, colour = q2), size = 3,
    check_overlap = TRUE
  ) +
  scale_colour_manual(values = c("black", "white"), guide = FALSE) +
  geom_text(
    data = points1, aes(x = X, y = Y - 0.03, label = num_2, colour = q2), size = 3,
    check_overlap = TRUE
  ) +
  geom_text(
    data = points2, aes(x = X + 0.07, y = Y + 0.09, label = PROVINCE), col = "black", size = 3,
    check_overlap = TRUE
  ) +
  geom_text(
    data = points2, aes(x = X + 0.07, y = Y + 0.03, label = num_2), col = "black", size = 3,
    check_overlap = TRUE
  ) +
  labs(fill = bquote(atop(NA, atop("Admissions hospitalières / \nHospitalisaties (x 100,000 hab./inw.)", bold(.(period2)))))) +
  theme_void() +
  theme(
    # Change legend
    legend.position = c(0.2, 0.22),
    legend.title = element_text(size = 12, color = "black"),
    legend.text = element_text(color = "black"),
    plot.margin = unit(c(+0.2, 0, -0.5, 3), "cm")
  )

empty_plot <- ggplot() + theme_void()

# save plot
png(file = "Belgian_Hospitalisations_COVID-19_augsept.png", width = 15 * 360, heigh = 7 * 360, units = "px", pointsize = 7, res = 300)
ggarrange(ggarrange(fig_map1, fig_map2, ncol = 1),
  grid.arrange(fig_trends_bel, empty_plot, empty_plot),
  grid.arrange(fig_trends, bottom = caption),
  ncol = 3, widths = c(1, 0.5, 1.5)
)
dev.off()
