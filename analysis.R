##################################################################
##                      Penguegg group                          ##
##      Changes rockhopper penguin in egg size over time        ##
##                        RQM Course                            ##
##################################################################

library(dplyr)
library(ggplot2)
library(geosphere)
library(scales)
library(RColorBrewer)
library(AICcmodavg)
library(tidyverse)

#########################import data##############################
rawEggSize <- read.csv("NRPE_eggSize_raw.csv")
names(rawEggSize) <- c('Source', 'SpecimenID', 'Location', 'Day',
                       'Month', 'Year', 'EggOrder', 'Length', 'Breadth', 'Volume', 'Reference')
##################################################################



###################Define discriminant function####################

##'Defines discriminant function with arbitrary cutoff
##'to determine egg-laying order of eggs listed as
##'unknown in dataset. Discriminant function comes from
##'Bond et al. 2016: 
##'D = 0.58*Length + 0.39*Breadth - 57.48
##'D = 0.73*Length + 0.50*Breadth - 72.39

assignOrder <- function(length, breadth, cutoff = 0.66){
  ##discriminant function
  ####From results
  #d <- length*0.73 + breadth*0.50 - 72.39
  
  ####From results, with signs switched
  #d <- -length*0.73 - breadth*0.50 + 72.39
  
  ####From the abstract
  d <- length*0.58 + breadth*0.39 - 57.48
  probB <- 1/(1+exp(-d))
  
  ###Discriminate
  if(probB > cutoff){
    return('B')
  }else if(probB < (1-cutoff)){
    return('A')
  }else{return('U')}
}
##################################################################

###########Define function for classifying oddballs###############
classifyOddballs <- function(eggdat, sdcutoff = 4){
  ###Identify means and sd's of breadth and length
  sdlength <- sd(eggdat$Length)
  sdbreadth <- sd(eggdat$Breadth)
  meanlength <- mean(eggdat$Length)
  meanbreadth <- mean(eggdat$Breadth)
  
  ##Classify abnormal eggs based on length and breadth
  ##based on supplied cutoff
  lengthAbnormal <- abs(eggdat$Length - meanlength)/sdlength > sdcutoff
  breadthAbnormal <- abs(eggdat$Breadth - meanbreadth)/sdbreadth > sdcutoff
  
  ##Change EggOrder to ODDBALL for eggs that are EITHER abnormal in length
  ##or abnormal in breadth
  eggdat$EggOrder <- as.character(eggdat$EggOrder)
  eggdat[lengthAbnormal | breadthAbnormal,'EggOrder'] <- 'ODDBALL'
  eggdat$EggOrder <- as.factor(eggdat$EggOrder)
  
  return(eggdat)
}
##################################################################



######################Apply discriminant function#################
eggSizeAssigned <- rawEggSize

##CHANGE CUTOFF HERE
AccuracyCutoff = 0.66
##

eggSizeAssigned[eggSizeAssigned$EggOrder == 'U',]$EggOrder <- mapply(FUN = assignOrder, 
                                                                     filter(eggSizeAssigned, EggOrder == 'U')$Length, 
                                                                     filter(eggSizeAssigned, EggOrder == 'U')$Breadth, 
                                                                     AccuracyCutoff)
##################################################################

########################Classify Oddballs#########################
##CHANGE CUTOFF HERE
oddballCutoff <- 3.5
##

eggSizeCleaned <- classifyOddballs(eggSizeAssigned, oddballCutoff)
##################################################################


###############Compare to Bond et al. assignments#################
##'The discriminant function above should have reproduced
##'the assignment procedure in Bond et al. The plots below
##'suggest that it has done so, with the exception of 
##'ODDBALLS, which we haven't been classified yet in this analysis
eggSizePub <- read.csv('NRPE_eggSize.csv')
par(mfrow = c(2,1))
boxplot(eggSizePub$length ~ eggSizePub$predEggOrder, main = 'Bond et al.')
boxplot(eggSizeCleaned$Length ~ eggSizeCleaned$EggOrder, main = 'Us')
plot(eggSizePub$predEggOrder, main = 'Bond et al.')
plot(eggSizeCleaned$EggOrder, main = 'Us')

summary(eggSizePub$predEggOrder)
summary(eggSizeCleaned$EggOrder)
##################################################################



#########Clean the data#######
eggSizeNoOdd <- filter(eggSizeCleaned, EggOrder %in% c('A', 'B'))
eggSizeNoOdd <- eggSizeNoOdd[-which(eggSizeNoOdd$Month == 1),]
##############################


##################Some basic descriptive statistics####################
boxplot(data = eggSizeCleaned[eggSizeCleaned$EggOrder == 'B',], Volume ~ Year, main = 'B Eggs')
boxplot(data = eggSizeCleaned[eggSizeCleaned$EggOrder == 'A',], Volume ~ Year, main = 'A Eggs')

boxplot(data = eggSizeCleaned[eggSizeCleaned$EggOrder == 'B',], Volume ~ Month, main = 'B Eggs')
boxplot(data = eggSizeCleaned[eggSizeCleaned$EggOrder == 'A',], Volume ~ Month, main = 'A Eggs')
# 
#########################Volume ~ Month############################
eggSizeNoOddMonth <- eggSizeNoOdd[complete.cases(eggSizeNoOdd$Month),]
eggSizeNoOddMonth$Month <- factor(eggSizeNoOddMonth$Month, levels = c(9,10,11))

m1 <- lm(Volume ~ Month, data = eggSizeNoOddMonth)
summary(m1)
boxplot(eggSizeNoOddMonth$Volume ~ eggSizeNoOddMonth$Month)
# ##without high leverage data point
# summary(lm(Volume ~ Month, data = eggSizeNoOdd[-936,]))
# 
# ##split by Egg Order
# summary(lm(Volume ~ Month, data = filter(eggSizeNoOdd, EggOrder == 'B'))) ## p = .00105
# summary(lm(Volume ~ Month, data = filter(eggSizeNoOdd, EggOrder == 'A'))) ##n.s
###################################################################
# 
# 
#########################Volume ~ Year#############################
eggSizeNoOddYear <- eggSizeNoOdd
eggSizeNoOddYear$Year <- factor(eggSizeNoOddYear$Year, levels = paste(unique(eggSizeNoOddYear$Year)[order(unique(eggSizeNoOddYear$Year), decreasing = T)], sep = ','))
m2 <- lm(Volume ~ Year, data = eggSizeNoOddYear)
summary(m2)
boxplot(data = eggSizeNoOddYear, Volume ~ Year)
# 
# ##Split by egg order
# summary(lm(Volume ~ Year, data = filter(eggSizeNoOdd, EggOrder == 'B'))) ##n.s
# summary(lm(Volume ~ Year, data = filter(eggSizeNoOdd, EggOrder == 'A'))) ##p = .00699
###################################################################
# 
# 
#######################Volume ~ Location###########################
# m3 <- lm(Volume ~ Location, data = eggSizeNoOdd)
# boxplot(Volume ~ Location, eggSizeNoOdd[eggSizeNoOdd$EggOrder == 'A',], main = 'A')
# boxplot(Volume ~ Location, eggSizeNoOdd[eggSizeNoOdd$EggOrder == 'B',], main = 'B')
# summary(lm(Volume ~  Location, data = filter(eggSizeNoOdd, EggOrder == 'B')))
# summary(lm(Volume ~  Location, data = filter(eggSizeNoOdd, EggOrder == 'A')))
###################################################################
##################################################################
#eggSizeNoOdd <- filter(eggSizeCleaned, EggOrder != 'ODDBALL')


#####################plot facets for each island#######
eggSizeNoOdd <- mutate(eggSizeNoOdd, Region = ifelse(ConvergentZone, 'Gough', 'Tristan'))
p <- ggplot(data= eggSizeNoOdd, aes(y = Volume, x = SST))+
  geom_point(fill = as.numeric(as.factor(eggSizeNoOdd$Location))) +
  geom_smooth(method = lm, se = FALSE)+
  xlab('Sea surface temperature')

p + facet_grid(. ~ Location)+
  theme_classic()


ggplot(data= eggSizeNoOdd, aes(y = Volume, x = Year))+
  geom_point() + 
  geom_smooth(method = lm)

ggplot(data= eggSizeNoOdd, aes(y = Volume, x = Year))+
  geom_point() + 
  geom_smooth(method = lm)


summary(lm(data = eggSizeNoOdd, Volume ~ SST + Location))

#################Model selection for basic variables###############
##'SST at different ranges
##'SSP at different ranges
##'Volume as response variable
##'Location
##'Month
##'Egg Order seperately
##'Year

#eggDat.A <- filter(eggSizeNoOdd, EggOrder == 'A')
#eggDat.B <- filter(eggSizeNoOdd, EggOrder == 'B')
eggs <- eggSizeNoOdd

###remove missing data
eggs <- eggs[complete.cases(eggs),]
eggs$ConvergentZone <- ifelse(eggs$Location == 'Gough', 1, 0)

###Model selection for basic variables - A eggs
eggsA <- filter(eggs, EggOrder == 'A')
mb1a <- lm(data = eggsA, Volume ~ 1)
mb2a <- lm(data = eggsA, Volume ~ Location)
mb3a <- lm(data = eggsA, Volume ~ Year)
mb4a <- lm(data = eggsA, Volume ~ Month)
mb5a <- lm(data = eggsA, Volume ~ ConvergentZone)
mb6a <- lm(data = eggsA, Volume ~ Month + Year)
mb7a <- lm(data = eggsA, Volume ~ Month + Location)
mb8a <- lm(data = eggsA, Volume ~ Month + ConvergentZone)
mb9a <- lm(data = eggsA, Volume ~ Year + Location)
mb10a <- lm(data = eggsA, Volume ~ Year + ConvergentZone)
mb11a <- lm(data = eggsA, Volume ~ Year + ConvergentZone + Month)
mb12a <- lm(data = eggsA, Volume ~ Year + Location + Month)

aic.a <- aictab(list(mb1a, mb2a, mb3a, mb4a, mb5a, mb6a, mb7a, mb8a, mb9a, mb10a, mb11a, mb12a))
aic.a


###Model selection for basic variables - B eggs
eggsB <- filter(eggs, EggOrder == 'B')
mb1b <- lm(data = eggsB, Volume ~ 1)
mb2b <- lm(data = eggsB, Volume ~ Location)
mb3b <- lm(data = eggsB, Volume ~ Year)
mb4b <- lm(data = eggsB, Volume ~ Month)
mb5b <- lm(data = eggsB, Volume ~ ConvergentZone)
mb6b <- lm(data = eggsB, Volume ~ Month + Year)
mb7b <- lm(data = eggsB, Volume ~ Month + Location)
mb8b <- lm(data = eggsB, Volume ~ Month + ConvergentZone)
mb9b <- lm(data = eggsB, Volume ~ Year + Location)
mb10b <- lm(data = eggsB, Volume ~ Year + ConvergentZone)
mb11b <- lm(data = eggsB, Volume ~ Year + ConvergentZone + Month)
mb12b <- lm(data = eggsB, Volume ~ Year + Location + Month)

aic.b <- aictab(list(mb1b, mb2b, mb3b, mb4b, mb5b, mb6b, mb7b, mb8b, mb9b, mb10b, mb11b, mb12b))
aic.b


###Model selection for basic variables - Together
mb1 <- lm(data = eggs, Volume ~ 1)
mb2 <- lm(data = eggs, Volume ~ Location)
mb3 <- lm(data = eggs, Volume ~ Year)
mb4 <- lm(data = eggs, Volume ~ Month)
mb5 <- lm(data = eggs, Volume ~ ConvergentZone)
mb6 <- lm(data = eggs, Volume ~ Month + Year)
mb7 <- lm(data = eggs, Volume ~ Month + Location)
mb8 <- lm(data = eggs, Volume ~ Month + ConvergentZone)
mb9 <- lm(data = eggs, Volume ~ Year + Location)
mb10 <- lm(data = eggs, Volume ~ Year + ConvergentZone)
mb11 <- lm(data = eggs, Volume ~ Year + ConvergentZone + Month)
mb12 <- lm(data = eggs, Volume ~ Year + Location + Month)

aic <- aictab(list(mb1, mb2, mb3, mb4, mb5, mb6, mb7, mb8, mb9, mb10, mb11, mb12))
aic


######Model selection with full dataset (not including month)####
eggSizeNoOdd$ConvergentZone <- ifelse(eggSizeNoOdd$Location == 'Gough', 1, 0)

###Model selection for basic variables with no month - A eggs
eggsA <- filter(eggSizeNoOdd, EggOrder == 'A')
mb1a.no.month <- lm(data = eggsA, Volume ~ 1)
mb2a.no.month <- lm(data = eggsA, Volume ~ Location)
mb3a.no.month <- lm(data = eggsA, Volume ~ Year)
mb4a.no.month <- lm(data = eggsA, Volume ~ ConvergentZone)
mb5a.no.month <- lm(data = eggsA, Volume ~ Year + Location)
mb6a.no.month <- lm(data = eggsA, Volume ~ Year + ConvergentZone)

aic.a.no.month <- aictab(list(mb1a.no.month, mb2a.no.month, mb3a.no.month, mb4a.no.month, mb5a.no.month, mb6a.no.month),
                         modnames = c('null', 'location', 'year','convergentZone', 'year+location', 'year+convergentZone'))
aic.a.no.month

###Model selection for basic variables with no month - B eggs
eggsB <- filter(eggSizeNoOdd, EggOrder == 'B')
mb1b.no.month <- lm(data = eggsB, Volume ~ 1)
mb2b.no.month <- lm(data = eggsB, Volume ~ Location)
mb3b.no.month <- lm(data = eggsB, Volume ~ Year)
mb4b.no.month <- lm(data = eggsB, Volume ~ ConvergentZone)
mb5b.no.month <- lm(data = eggsB, Volume ~ Year + Location)
mb6b.no.month <- lm(data = eggsB, Volume ~ Year + ConvergentZone)

aic.b.no.month <- aictab(list(mb1b.no.month, mb2b.no.month, mb3b.no.month, mb4b.no.month, mb5b.no.month, mb6b.no.month),
                         modnames = c('null', 'location', 'year','convergentZone', 'year+location', 'year+convergentZone'))
aic.b.no.month



######Modeling egg size with environmental data####

####Read in environmental data####
edatS_full <- read.fwf('Environmental Data1800/MSG2.S.enh.180001.201412_1', widths = c(6,4,3,7,8,5,8,7,8,8,8,8,8,9,8,8), skip = 2, head = F)
names(edatS_full) <- c('Year', 'Mon', 'BSZ', 'BLO', 'BLA', 'PID2', 'S1', 'S3', 'S5', 'M','N','S','D','HT', 'X', 'Y')
edatS_full[edatS_full$HT == -9999,'HT'] <- NA 

edatP_full <- read.fwf('Environmental Data1800/MSG2.P.enh.180001.201412_1', widths = c(6,4,3,7,8,5,8,7,8,8,8,8,8,9,8,8), skip = 2, head = F)
names(edatP_full) <- c('Year', 'Mon', 'BSZ', 'BLO', 'BLA', 'PID2', 'S1', 'S3', 'S5', 'M','N','S','D','HT', 'X', 'Y')
edatP_full[edatP_full$HT == -9999,'HT'] <- NA 

##Trim data to reduce subsetting runtimes
edatS <- filter(edatS_full, Year %in% unique(eggSizeNoOdd$Year))
edatP <- filter(edatP_full, Year %in% unique(eggSizeNoOdd$Year))
##################################################################


####################Calculate distances to islands################
###Coordinates of the center of the Tristan da Cunha island cluster

###Define bins for binning distances
#bins <- c(0, 250, 500, 1000, 2100, 100000)
bins <- c(0,400, 1000000000)
bin_names <- c('near', 'far')
#bin_names <- c('inner_1', 'med_2', 'med_3', 'outer_4', 'outside_5')

###Island locations
tristanLat <- -37.26
tristanLon <- -12.47
goughLat <- -40.31
goughLon <- -9.93


edatP$Lon <- edatP$BLO + edatP$X
edatP$Lat <- edatP$BLA + edatP$Y
edatP[edatP$Lon > 180,'Lon'] <- edatP[edatP$Lon > 180,'Lon'] - 360

##Dist in kilometers
edatP$distTristan <- distGeo(c(tristanLon, tristanLat), mapply(c, edatP[,c('Lon', 'Lat')]))/1000
edatP$distTristanBin <- cut(edatP$distTristan, breaks = bins, right = T, labels = bin_names)
edatP$distGough <- distGeo(c(goughLon, goughLat), mapply(c, edatP[,c('Lon', 'Lat')]))/1000
edatP$distGoughBin <- cut(edatP$distGough, breaks = bins, right = T, labels = bin_names)

edatS$Lon <- edatS$BLO + edatS$X
edatS$Lat <- edatS$BLA + edatS$Y
edatS[edatS$Lon > 180,'Lon'] <- edatS[edatS$Lon > 180,'Lon'] - 360

###distance in kilometers
edatS$distTristan <- distGeo(c(tristanLon, tristanLat), mapply(c, edatS[,c('Lon', 'Lat')]))/1000
edatS$distTristanBin <- cut(edatS$distTristan, breaks = bins, right = T, labels = bin_names)
edatS$distGough <- distGeo(c(goughLon, goughLat), mapply(c, edatS[,c('Lon', 'Lat')]))/1000
edatS$distGoughBin <- cut(edatS$distGough, breaks = bins, right = T, labels = bin_names)

colors <- brewer.pal(5, 'Greens')
colors2 <- brewer.pal(5, 'Blues')
#plot(mapply(c, edatP[,c('Lon', 'Lat')]), col = alpha(colors[edatP$distTristanBin], 0.3))
#points(mapply(c, edatP[,c('Lon', 'Lat')]), col = alpha(colors[edatP$distGoughBin], 0.1))
#text(x = c(tristanLon, goughLon), y = c(tristanLat, goughLat), labels = c('T', 'G'), col = 'white')

edatS_T_range <- filter(edatP, distTristanBin == 'near')
edatP_G_range <- filter(edatP, distGoughBin == 'near')
ggplot(aes(x = Lon, y = Lat), data = edatP_T_range) +
  geom_raster(alpha = 0.5, fill = colors2[edatP_T_range$distTristanBin], interpolate = T)+
  geom_raster(aes(x = Lon, y = Lat), fill = colors2[edatP_G_range$distGoughBin], alpha =0.5, data = edatP_G_range)

ggplot(aes(x = Lon, y = Lat), data = edatS_T_range) +
  geom_raster(alpha = 0.5, fill = scale(edatS_T_range$M), interpolate = T)+
  scale_fill_gradient2(low = 'red', high = 'blue')
  #geom_raster(aes(x = Lon, y = Lat), fill = colors2[edatP_G_range$distGoughBin], alpha =0.5, data = edatP_G_range)

##'Potential bin categories
##'0-250
##'0-500
##'0-1000
##'0-2000
##################################################################


################Aggregate means of environmental data#############

##Timing of different lifehistory periods - Cuthbert 2013 (penguins natural history and conservation)
IncubationMonths <- c(7,8,9,10)
ForagingMonthsLiberal <- c(4,5,6,7)
ForagingMonthsCons <- c(5,6)
BroodingMonths <- c(10,11,12,1)

#LayingMonthsG <- c(8,9)
LayingMonthsG <- 8
LayingMonthsT <- 8



# ###Foraging ranges from different lifehistory periods - from IUCN 2016 
# IncubationDistT <- 800
# IncubationDistG <- 670
# ForagingDistT <- 2100
# ForagingDistG <- 2100
# BroodingDistT <- 35
# BroodingDistG <- 24





for(row in 1:length(eggSizeNoOdd[,1])){
  year <- eggSizeNoOdd[row,'Year']
  location <- ifelse(eggSizeNoOdd[row,'Location'] == 'Gough', 'G', 'T')
  if(location == 'T'){
    eggSizeNoOdd[row,'SST'] <- mean(filter(edatS, Mon %in% LayingMonthsT, Year == year, distTristanBin == 'near')$M, na.rm = T)
    eggSizeNoOdd[row,'SSP'] <- mean(filter(edatP, Mon %in% LayingMonthsT, Year == year, distTristanBin == 'near')$M, na.rm = T)
  }else{
    eggSizeNoOdd[row,'SST'] <- mean(filter(edatS, Mon %in% LayingMonthsG, Year == year, distGoughBin == 'near')$M, na.rm = T)
    eggSizeNoOdd[row,'SSP'] <- mean(filter(edatP, Mon %in% LayingMonthsG, Year == year, distGoughBin == 'near')$M, na.rm = T)
  }
}

#########################Model volume mean and variance by year#########

summary(lm(data = eggSizeNoOdd, Volume ~ Year))
summary(lm(data = eggSizeNoOdd, Volume ~ SST))

eggSizeNoOdd %>%
  group_by(Year, ConvergentZone, EggOrder) %>% summarize(u_volume = mean(Volume, na.rm = T),
                               sd_volume = sd(Volume, na.rm = T),
                               num_samples = length(Volume),
                               SST = mean(SST),
                               SSP = mean(SSP),
                               ran_sst = mean(ran_sst)) -> eggSizeByYear

summary(lm(data = eggSizeByYear, u_volume ~ SST + EggOrder, weights = num_samples))
summary(lm(data = eggSizeByYear, u_volume ~ SSP + EggOrder, weights = num_samples))
summary(lm(data = eggSizeByYear, u_volume ~ ran_sst + EggOrder, weights = num_samples))
summary(lm(data = eggSizeByYear, sd_volume ~ SST + EggOrder, weights = num_samples))
summary(lm(data = eggSizeByYear, sd_volume ~ SSP + EggOrder, weights = num_samples))
summary(lm(data = eggSizeByYear, sd_volume ~ ran_sst + EggOrder, weights = num_samples))

summary(lm(data = filter(eggSizeByYear, ConvergentZone == 0), u_volume ~ SST + EggOrder, weights = num_samples))


#####Model both eggs together with basic variables and environmental variables#######
m_tog_1 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder)
m_tog_2 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Year)
m_tog_3 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location)
m_tog_4 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + SST)
m_tog_5 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + SSP)
m_tog_6 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone)
m_tog_7 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + Year)
m_tog_8 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + Year)
m_tog_9 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + SST)
m_tog_10 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + SSP)
m_tog_11 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + SST)
m_tog_12 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + SSP)
m_tog_13 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Year + SST)
m_tog_14 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Year + SSP)
m_tog_15 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + Year + SST)
m_tog_16 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + Year + SSP)
m_tog_17 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + Year + SST)
m_tog_18 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + Year + SSP)

aictab(cand.set = list(m_tog_1, m_tog_2, m_tog_3, m_tog_4, m_tog_5, m_tog_6, m_tog_7, m_tog_8,
                       m_tog_9, m_tog_10, m_tog_11, m_tog_12, m_tog_13, m_tog_14, m_tog_15,
                       m_tog_16, m_tog_17, m_tog_18),
       modnames = c('eggO', 'eggO + year', 'eggO + location', 'eggO + SST', 'eggO + SSP',
                       'eggO + cz', 'eggO + location + year', 'eggO + cz + year', 'eggO + location + SST',
                       'eggO + location + SSP', 'eggO + cz + SST', 'eggO + cz + SSP', 'eggO + year + SST',
                       'eggO + year + SSP', 'eggO + location + year + SST', 'eggO + location + year + SSP',
                       'eggO + cz + year + SST', 'eggO + cz + year + SSP')) 

summary(m_tog_9)
summary(m_tog_10)

######TRACY#####

#Analysis within island across years
eggSizeNoOdd$ConvergentZone <- ifelse(eggSizeNoOdd$Location == 'Gough', 1, 0)

data.night <- eggSizeNoOdd %>% filter(Location == 'Nightingale')

m_night_1 <- lm(data = data.night, Volume ~ EggOrder)
m_night_2 <- lm(data = data.night, Volume ~ EggOrder + Year)
#m_night_3 <- lm(data = data.night, Volume ~ EggOrder + SST)
#m_night_4 <- lm(data = data.night, Volume ~ EggOrder + Year + SST)

aictab(list(m_night_1, m_night_2))
summary(m_night_2)
#Model including Year scores 2.8 better on AIC, coef for Year is 0.05 and is significant

#Analysis within island across years
data.tdc <- eggSizeNoOdd %>% filter(Location == 'Tristan')

m_tdc_1 <- lm(data = data.tdc, Volume ~ EggOrder)
m_tdc_2 <- lm(data = data.tdc, Volume ~ EggOrder + Year)
#m_tdc_3 <- lm(data = data.tdc, Volume ~ EggOrder + SST)
#m_tdc_4 <- lm(data = data.tdc, Volume ~ EggOrder + Year + SST)

aictab(list(m_tdc_1, m_tdc_2))
summary(m_tdc_2)
#Model without Year is better

#Analysis within year across islands
data.2014 <- eggSizeNoOdd %>% filter(Year == '2014')

m_2014_1 <- lm(data = data.2014, Volume ~ EggOrder)
m_2014_2 <- lm(data = data.2014, Volume ~ EggOrder + ConvergentZone)
m_2014_3 <- lm(data = data.2014, Volume ~ EggOrder + Location)
#m_2014_3 <- lm(data = data.2014, Volume ~ EggOrder + SST)
#m_2014_4 <- lm(data = data.2014, Volume ~ EggOrder + ConvergentZone + SST)

aictab(list(m_2014_1, m_2014_2, m_2014_3))
summary(m_2014_2)
#Model including location is better than model including SCZ

#Analysis with basic variables
m_basic_1 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder)
m_basic_2 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Year)
m_basic_3 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone)
m_basic_4 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + Year)
m_basic_5 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location)
m_basic_6 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + Location + Year)
#m_basic_7 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone | Location)
#m_basic_8 <- lm(data = eggSizeNoOdd, Volume ~ EggOrder + ConvergentZone + Year | Location)

aictab(list(m_basic_1, m_basic_2, m_basic_3, m_basic_4, m_basic_5, m_basic_6))

#Model with Location is best & is not distinguishable from model with Location + Year
#Model with SCZ is next best & better without Year

#Analysis with residuals

#Model using residuals from ConvergentZone & Year
m_resid_1 <- lm(data = eggSizeNoOdd, m_basic_4$residuals ~ SST) #residuals from SCZ + Year
m_resid_2 <- lm(data = eggSizeNoOdd, m_basic_4$residuals ~ Location) #residuals from SCZ + Year

aictab(list(m_resid_1, m_resid_2))
summary(m_resid_1)
#Model with SST is better, coef is 0.17 and is not significant

#Model using residuals from ConvergentZone
m_resid_3 <- lm(data = eggSizeNoOdd, m_basic_3$residuals ~ SST) #residuals from SCZ
m_resid_4 <- lm(data = eggSizeNoOdd, m_basic_3$residuals ~ Year) #residuals from SCZ
m_resid_5 <- lm(data = eggSizeNoOdd, m_basic_3$residuals ~ Location) #residuals from SCZ

aictab(list(m_resid_3, m_resid_4, m_resid_5))
summary(m_resid_3)
#Model with SST is better, coef is 0.17 and is not significant

########Figures for poster###################
#scatterplot for changes over years
ggplot(data= eggSizeNoOdd, aes(y = Volume, x = Year))+
  geom_point() + theme_classic() + ggtitle("Overall change in egg volume over time")+ 
  geom_smooth(method = lm) + theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.text = element_text(size = 16), axis.title = element_text(size = 18,face="bold")) +
  theme(plot.title = element_text(size = rel(2))) 

#scatterplot for changes in SST
ggplot(data= eggSizeNoOdd, aes(y = Volume, x = SST))+
  geom_point() + theme_classic() + ggtitle("Potential effect of sea surface on egg volume")+
  geom_smooth(method = lm) + theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.text = element_text(size = 16), axis.title = element_text(size = 18,face="bold")) +
  theme(plot.title = element_text(size = rel(2))) + xlab("Sea surface temperature (°C)")

#boxplot comparing a and b eggs
ggplot(data = eggSizeNoOdd, aes(y=Volume,x=EggOrder,fill=EggOrder)) + geom_boxplot() + 
  theme_classic() + ggtitle("B eggs are larger than A eggs") +xlab("Egg Order") +ylab("Volume (units?)")+
  theme(plot.title = element_text(hjust = 0.5)) + 
  theme(axis.text = element_text(size = 12), axis.title = element_text(size = 16,face="bold")) +
  theme(plot.title = element_text(size = rel(2))) + scale_fill_brewer(palette = "Set3")

#boxplot comparing egg size among islands
ggplot(data = eggSizeNoOdd, aes(y=Volume,x=Location,fill=Location)) + geom_boxplot() + 
  theme_classic() + ggtitle("Variation among islands") +xlab("Island") +ylab("Volume (units?)")+
  theme(axis.text = element_text(size = 16), axis.title = element_text(size = 18,face="bold")) +
  theme(plot.title = element_text(hjust = 0.5)) + theme(plot.title = element_text(size = rel(2))) + 
  scale_fill_brewer(palette="Set1")

##+ stat_summary(fun.data = give.n, geom = "text", 
##        position = position_dodge(height = 0, width = .75), size = 3)

#graph panel for SST
ggplot(data = eggSizeNoOdd, aes(y=Volume, x=SST)) + geom_point() + facet_grid(Location ~ EggOrder) +
  geom_smooth(method = "lm", se = FALSE)+ theme_bw() + theme(panel.grid.major = element_blank(),
                                                             panel.grid.minor = element_blank(),
                                                             strip.background = element_rect(colour="white", fill="white"),
                                                             panel.border = element_rect(colour = "black")) + ggtitle("Comparisons among islands") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.text = element_text(size = 16), axis.title = element_text(size = 18,face="bold"),
        strip.text = element_text(size = 16)) +
  theme(plot.title = element_text(size = rel(2))) + xlab("Sea surface temperature (°C)")


####Notes

##Model with weighting parameter, mean and variance separately
#reshape data to be modeling mean and variance
#uVolume ~ Location + SST, weights = NumSubSamples
#sdVolume ~ Location + SST, weights = NumSubSamples

#Model with location, then model residuals with SST





# # ###Runs REALLY slow
# # for(row in 1:length(eggSizeNoOdd[,1])){
# #   year <- eggSizeNoOdd[row,'Year']
# #   location <- ifelse(eggSizeNoOdd[row,'Location'] == 'Gough', 'G', 'T')
# #   if(location == 'T'){
# #     #Liberal, SST
# #     eggSizeNoOdd[row,'inner1_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'outside_5')$M, na.rm = T)
# #     #Conservative, SST
# #     eggSizeNoOdd[row,'inner1_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'outside_5')$M, na.rm = T)
# #     #Liberal, SSP
# #     eggSizeNoOdd[row,'inner1_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distTristanBin == 'outside_5')$M, na.rm = T)
# #     #Conservative, SSP
# #     eggSizeNoOdd[row,'inner1_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distTristanBin == 'outside_5')$M, na.rm = T)
# #   }else{
# #     #Liberal, SST
# #     eggSizeNoOdd[row,'inner1_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SST_lib'] <- mean(filter(edatS, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'outside_5')$M, na.rm = T)
# #     #Conservative, SST
# #     eggSizeNoOdd[row,'inner1_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SST_cons'] <- mean(filter(edatS, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'outside_5')$M, na.rm = T)
# #     #Liberal, SSP
# #     eggSizeNoOdd[row,'inner1_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SSP_lib'] <- mean(filter(edatP, Mon %in% ForagingMonthsLiberal, Year == year, distGoughBin == 'outside_5')$M, na.rm = T)
# #     #Conservative, SSP
# #     eggSizeNoOdd[row,'inner1_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'inner_1')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med2_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'med_2')$M, na.rm = T)
# #     eggSizeNoOdd[row,'med3_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'med_3')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outer4_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'outer_4')$M, na.rm = T)
# #     eggSizeNoOdd[row,'outside5_SSP_cons'] <- mean(filter(edatP, Mon %in% ForagingMonthsCons, Year == year, distGoughBin == 'outside_5')$M, na.rm = T)
# #   }
# # }
# 
# complete.cases(eggSizeNoOdd[,12:length(eggSizeNoOdd)])
# #####################################################################
# 
# 
# #####Ecological models of A eggs. Each model is ecological variable + convergentZone#####
# eggSizeNoOdd_A <- filter(eggSizeNoOdd, EggOrder == 'A')
# #temperature
# mA.inner1_sst_cons <- lm(data = eggSizeNoOdd_A, Volume ~ inner1_SST_cons + ConvergentZone)
# mA.med2_sst_cons <- lm(data = eggSizeNoOdd_A, Volume ~ med2_SST_cons + ConvergentZone)
# mA.med3_sst_cons <- lm(data = eggSizeNoOdd_A, Volume ~ med3_SST_cons + ConvergentZone)
# mA.outer4_sst_cons <- lm(data = eggSizeNoOdd_A, Volume ~ outer4_SST_cons + ConvergentZone)
# mA.outside5_sst_cons <- lm(data = eggSizeNoOdd_A, Volume ~ outside5_SST_cons + ConvergentZone)
# 
# mA.inner1_sst_lib <- lm(data = eggSizeNoOdd_A, Volume ~ inner1_SST_lib + ConvergentZone)
# mA.med2_sst_lib <- lm(data = eggSizeNoOdd_A, Volume ~ med2_SST_lib + ConvergentZone)
# mA.med3_sst_lib <- lm(data = eggSizeNoOdd_A, Volume ~ med3_SST_lib + ConvergentZone)
# mA.outer4_sst_lib <- lm(data = eggSizeNoOdd_A, Volume ~ outer4_SST_lib + ConvergentZone)
# mA.outside5_sst_lib <- lm(data = eggSizeNoOdd_A, Volume ~ outside5_SST_lib + ConvergentZone)
# 
# #pressure
# mA.inner1_ssp_cons <- lm(data = eggSizeNoOdd_A, Volume ~ inner1_SSP_cons + ConvergentZone)
# mA.med2_ssp_cons <- lm(data = eggSizeNoOdd_A, Volume ~ med2_SSP_cons + ConvergentZone)
# mA.med3_ssp_cons <- lm(data = eggSizeNoOdd_A, Volume ~ med3_SSP_cons + ConvergentZone)
# mA.outer4_ssp_cons <- lm(data = eggSizeNoOdd_A, Volume ~ outer4_SSP_cons + ConvergentZone)
# mA.outside5_ssp_cons <- lm(data = eggSizeNoOdd_A, Volume ~ outside5_SSP_cons + ConvergentZone)
# 
# mA.inner1_ssp_lib <- lm(data = eggSizeNoOdd_A, Volume ~ inner1_SSP_lib + ConvergentZone)
# mA.med2_ssp_lib <- lm(data = eggSizeNoOdd_A, Volume ~ med2_SSP_lib + ConvergentZone)
# mA.med3_ssp_lib <- lm(data = eggSizeNoOdd_A, Volume ~ med3_SSP_lib + ConvergentZone)
# mA.outer4_ssp_lib <- lm(data = eggSizeNoOdd_A, Volume ~ outer4_SSP_lib + ConvergentZone)
# mA.outside5_ssp_lib <- lm(data = eggSizeNoOdd_A, Volume ~ outside5_SSP_lib + ConvergentZone)
# 
# 
# 
# ##model comparison
# A.ecol.aic <- aictab(list(mA.inner1_sst_cons,mA.med2_sst_cons,mA.med3_sst_cons,mA.outer4_sst_cons,mA.outside5_sst_cons,
#                           mA.inner1_sst_lib,mA.med2_sst_lib,mA.med3_sst_lib,mA.outer4_sst_lib,mA.outside5_sst_lib,
#                           mA.inner1_ssp_cons,mA.med2_ssp_cons,mA.med3_ssp_cons,mA.outer4_ssp_cons,mA.outside5_ssp_cons,
#                           mA.inner1_ssp_lib,mA.med2_ssp_lib,mA.med3_ssp_lib,mA.outer4_ssp_lib,mA.outside5_ssp_lib),
#                      modnames = c('inner1_sst_cons','med2_sst_cons','med3_sst_cons','outer4_sst_cons','outside5_sst_cons',
#                                   'inner1_sst_lib','med2_sst_lib','med3_sst_lib','outer4_sst_lib','outside5_sst_lib',
#                                   'inner1_ssp_cons','med2_ssp_cons','med3_ssp_cons','outer4_ssp_cons','outside5_ssp_cons',
#                                   'inner1_ssp_lib','med2_ssp_lib','med3_ssp_lib','outer4_ssp_lib','outside5_ssp_lib'))
# 
# 
# ##
# #####Ecological models of B eggs. Each model is ecological variable + convergentZone#####
# ##
# eggSizeNoOdd_B <- filter(eggSizeNoOdd, EggOrder == 'B')
# 
# mB.inner1_sst_cons <- lm(data = eggSizeNoOdd_B, Volume ~ inner1_SST_cons + Location)
# mB.med2_sst_cons <- lm(data = eggSizeNoOdd_B, Volume ~ med2_SST_cons + Location)
# mB.med3_sst_cons <- lm(data = eggSizeNoOdd_B, Volume ~ med3_SST_cons + Location)
# mB.outer4_sst_cons <- lm(data = eggSizeNoOdd_B, Volume ~ outer4_SST_cons + Location)
# mB.outside5_sst_cons <- lm(data = eggSizeNoOdd_B, Volume ~ outside5_SST_cons + Location)
# 
# mB.inner1_sst_lib <- lm(data = eggSizeNoOdd_B, Volume ~ inner1_SST_lib + Location)
# mB.med2_sst_lib <- lm(data = eggSizeNoOdd_B, Volume ~ med2_SST_lib + Location)
# mB.med3_sst_lib <- lm(data = eggSizeNoOdd_B, Volume ~ med3_SST_lib + Location)
# mB.outer4_sst_lib <- lm(data = eggSizeNoOdd_B, Volume ~ outer4_SST_lib + Location)
# mB.outside5_sst_lib <- lm(data = eggSizeNoOdd_B, Volume ~ outside5_SST_lib + Location)
# 
# #pressure
# mB.inner1_ssp_cons <- lm(data = eggSizeNoOdd_B, Volume ~ inner1_SSP_cons + Location)
# mB.med2_ssp_cons <- lm(data = eggSizeNoOdd_B, Volume ~ med2_SSP_cons + Location)
# mB.med3_ssp_cons <- lm(data = eggSizeNoOdd_B, Volume ~ med3_SSP_cons + Location)
# mB.outer4_ssp_cons <- lm(data = eggSizeNoOdd_B, Volume ~ outer4_SSP_cons + Location)
# mB.outside5_ssp_cons <- lm(data = eggSizeNoOdd_B, Volume ~ outside5_SSP_cons + Location)
# 
# mB.inner1_ssp_lib <- lm(data = eggSizeNoOdd_B, Volume ~ inner1_SSP_lib + Location)
# mB.med2_ssp_lib <- lm(data = eggSizeNoOdd_B, Volume ~ med2_SSP_lib + Location)
# mB.med3_ssp_lib <- lm(data = eggSizeNoOdd_B, Volume ~ med3_SSP_lib + Location)
# mB.outer4_ssp_lib <- lm(data = eggSizeNoOdd_B, Volume ~ outer4_SSP_lib + Location)
# mB.outside5_ssp_lib <- lm(data = eggSizeNoOdd_B, Volume ~ outside5_SSP_lib + Location)
# 
# 
# ##model comparison
# B.ecol.aic <- aictab(list(mB.inner1_sst_cons,mB.med2_sst_cons,mB.med3_sst_cons,mB.outer4_sst_cons,mB.outside5_sst_cons,
#                           mB.inner1_sst_lib,mB.med2_sst_lib,mB.med3_sst_lib,mB.outer4_sst_lib,mB.outside5_sst_lib,
#                           mB.inner1_ssp_cons,mB.med2_ssp_cons,mB.med3_ssp_cons,mB.outer4_ssp_cons,mB.outside5_ssp_cons,
#                           mB.inner1_ssp_lib,mB.med2_ssp_lib,mB.med3_ssp_lib,mB.outer4_ssp_lib,mB.outside5_ssp_lib),
#                      modnames = c('inner1_sst_cons','med2_sst_cons','med3_sst_cons','outer4_sst_cons','outside5_sst_cons',
#                                   'inner1_sst_lib','med2_sst_lib','med3_sst_lib','outer4_sst_lib','outside5_sst_lib',
#                                   'inner1_ssp_cons','med2_ssp_cons','med3_ssp_cons','outer4_ssp_cons','outside5_ssp_cons',
#                                   'inner1_ssp_lib','med2_ssp_lib','med3_ssp_lib','outer4_ssp_lib','outside5_ssp_lib'))
# 
