
library(tidyverse)
library(lubridate)
library(stringr)
library(lme4)
library("gridExtra")     

setwd("/Users/gabrielwisswaesser/desktop/mora")

op <- par(no.readonly=TRUE)

dddd <- gsub(Sys.Date(), pattern="-", replacement="")

## Read MBS data
predictors <- read_csv("./westcascades/data/weekly-predictors_MBS_model_20210222.csv")
onsite <- read_csv("./westcascades/data/weeklycombined_onsite.csv")

## Filtering to only include sites in mbs_sites_w_ir.shp
sites <- foreign::read.dbf("./westcascades/data/mbs_sites_w_ir_20200228.dbf", as.is = TRUE)
onsite <- onsite %>% filter(siteid %in% sites$siteid) 


## Bind together
tomprew <- onsite %>%
  left_join(predictors, by = c("yearmod", "weekmod", "siteid", "weekstart"))

## transformations for reg assumptions
tomprew$weekly_viz_lg <- log1p(tomprew$weekly_viz)
tomprew$pudlg <- log1p(tomprew$pud)
tomprew$tudlg <- log1p(tomprew$tud)
tomprew$iudlg <- log1p(tomprew$iud)
tomprew$wudlg <- log1p(tomprew$wud)
tomprew$audlg <- log1p(tomprew$aud)
tomprew$prcplg <- log1p(tomprew$PRCP)

## National Forest Model (NF model)
weekly_mod <- lm(weekly_viz_lg ~ weekmod + I(weekmod^2) + 
                   hols + pudlg + tudlg + iudlg + audlg +prcplg,
                 data = tomprew)
summary(weekly_mod) # Multiple R-squared:  0.7357,	Adjusted R-squared:  0.7347
anova(weekly_mod)

plot(weekly_mod$model$weekly_viz_lg ~ fitted(weekly_mod)); abline(a=0, b=1)
cor(weekly_mod$model$weekly_viz_lg, fitted(weekly_mod))

#load MORA predictors and on-site counts
mora_predictors <- read_csv("data/weekly-predictors_US_model_20210314.csv")
mora_onsite <- read_csv("../mora-people-mora-problems/data/processed/weekly_counts.csv")

# Siteid from string to int
temp_column <- str_sub(mora_predictors$siteid, 1, 2)
temp_column <- as.numeric(temp_column)
mora_predictors$siteid<-temp_column

## transformations for reg assumptions
mora_predictors$pudlg <- log1p(mora_predictors$pud)
mora_predictors$tudlg <- log1p(mora_predictors$tud)
mora_predictors$iudlg <- log1p(mora_predictors$iud)
mora_predictors$audlg <- log1p(mora_predictors$aud)
mora_predictors$prcplg <- log1p(mora_predictors$prcp)

# Merge predictors and onsite tables

mora_df <- merge(mora_predictors, mora_onsite[ ,c("siteid","weekstart","weekly_viz","weekly_viz_raw")], by=c("siteid","weekstart"))

# Tables to store results
NF_cor <- numeric()#rep(NA,simss)
NF_R2 <- numeric()#rep(NA,simss)
third_cor <- numeric()#rep(NA,simss)
third_R2 <- numeric()#rep(NA,simss)
rando_cor <- numeric()

# Plot results or not
#plotit <- "y"
plotit <- "no"

# Simulate using diff slices of 1/3 vs 2/3 MORA data
for(i in 1:500) {
  
  # 2/3 random sample of table
  two_thirds_ind <- sample(nrow(mora_df), nrow(mora_df)*(2/3))
  one_thirds_ind <- which(!1:nrow(mora_df) %in% two_thirds_ind)
  mora_two_thirds_df <- mora_df[two_thirds_ind, ]
  
  # Rename and drop columns due to merging
  mora_two_thirds_df <- rename(mora_two_thirds_df, Trail_name = site_name)
  mora_two_thirds_df <- subset(mora_two_thirds_df,select= -tmax_avg)
  mora_two_thirds_df$weekly_viz_lg <- log1p(mora_two_thirds_df$weekly_viz)
  
  #pull 1/3 mora_df data for in-sample and create 2/3 outsample
  mora_third_df <- mora_df[one_thirds_ind, ]

  #rename, drop, transform columns that don't match tomprew
  mora_third_df <- rename(mora_third_df, Trail_name = site_name)
  mora_third_df$weekly_viz_lg <- log1p(mora_third_df$weekly_viz)

  # Create predictions using weekly_mod
  mora_two_thirds_df$fit <- predict(weekly_mod, mora_two_thirds_df)
  
  ##### NF model and plotting
  
  mora_NF_lm <- lm(mora_two_thirds_df$weekly_viz_lg ~ mora_two_thirds_df$fit)
  NF_cor <- c(NF_cor, cor(mora_two_thirds_df$weekly_viz_lg, mora_two_thirds_df$fit, use="complete.obs"))

  lab_cor <- paste("Pearson's =", round(NF_cor[length(NF_cor)], 2))
  lab_R2 <-  paste("Multiple R-squared =", round((NF_cor*NF_cor), 2))
  
  if (plotit == "y") {
    week_count_viz_NF = ggplot(mora_two_thirds_df, aes(x=fit, y = weekly_viz_lg)) + 
      geom_point() + geom_smooth(data =mora_two_thirds_df, method="lm")
    
    print(week_count_viz_NF + ggtitle(paste("Model 1: NF Model Using MORA Predictor's\n",lab_cor,"\n",lab_R2)) +
      theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
            axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))
  }


    
  ##### NF + MORA model and plotting
  
  #drop and rename columns in tomprew to match mora_third, creating tomprew_lite
  tomprew_lite <- subset(tomprew,select = -c(TMAX_avg,days_ir_pc,days_ir,days_pc,days_closed,wud,wudlg,eud,UseNew))
  tomprew_lite <- tomprew_lite %>% rename(prcp = PRCP)
  
  # Add 0.1 to siteids so they're unique from  tomprew_lite
  mora_third_df$siteid <- mora_third_df$siteid + 0.1
  mora_two_thirds_df$siteid <- mora_two_thirds_df$siteid + 0.1
  
  # Reorder, check for differences between df's and combine
  mora_third_df_reordered <- mora_third_df[ , colnames(tomprew_lite)]
  all(colnames(mora_third_df_reordered) == colnames(tomprew_lite)) 
  tomprew_lite_mora_third <- rbind(tomprew_lite, mora_third_df_reordered)
  
  # Model with 1/3 MORA data
  weekly_mod_with_third <- lm(weekly_viz_lg ~ weekmod + I(weekmod^2) + 
                     hols + pudlg + tudlg + iudlg + audlg +prcplg,
                   data = tomprew_lite_mora_third)
  summary(weekly_mod_with_third)
  anova(weekly_mod_with_third)
  cor(weekly_mod_with_third$model$weekly_viz_lg, fitted(weekly_mod_with_third))

  ########## predictions with 1/3 MORA model
  mora_two_thirds_df$fit <- predict(weekly_mod_with_third, mora_two_thirds_df)
  mora_two_thirds_df$yearmod <- as.factor(mora_two_thirds_df$yearmod)
  two_third_lm <- lm(mora_two_thirds_df$weekly_viz_lg ~ mora_two_thirds_df$fit)

  third_cor <- c(third_cor, cor(mora_two_thirds_df$weekly_viz_lg, mora_two_thirds_df$fit, use="complete.obs"))

  lab_cor_third <- paste("Pearson's =", round(third_cor[length(third_cor)], 2))
  lab_R2_third <-  paste("Multiple R-squared =", round((third_cor*third_cor), 2))
  
  summary(two_third_lm)
  
  ################################### ggplot 1/3 scatters
  if (plotit == "y") {
    week_count_viz_third = ggplot(mora_two_thirds_df, aes(x=fit, y = weekly_viz_lg)) + 
      geom_point() + geom_smooth(data =mora_two_thirds_df, method="lm")
    
    print(week_count_viz_third + ggtitle(paste("Model 2: NF Model with 1/3 MORA in-sample\n",lab_cor_third,"\n",lab_R2_third)) + 
      theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
            axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))
  }


  ##### Random effects addition
  weekly_rando_mod <- lmer(weekly_viz_lg ~ -1 + weekmod + I(weekmod^2) + 
                          hols + pudlg + tudlg + iudlg + audlg + prcplg + (1|siteid),
                          data = tomprew_lite_mora_third)

  mora_two_thirds_df$random_fit <- predict(weekly_rando_mod, newdata = mora_two_thirds_df, allow.new.levels = T)

  rando_cor <- c(rando_cor, cor(mora_two_thirds_df$weekly_viz_lg, mora_two_thirds_df$random_fit, use="pairwise.complete.obs"))
  rando_R2_lab <- paste("Multiple R-squared =", round((rando_cor^2), 2))
  if (plotit=="y") {
    lab_cor_rando <- paste("Pearson's:", round(rando_cor[length(rando_cor)], 2))
    rando_plot = ggplot(mora_two_thirds_df, aes(x=random_fit, y = weekly_viz_lg)) + 
      geom_point() + geom_smooth(data =mora_two_thirds_df, method="lm")

    print(rando_plot + ggtitle(paste("Model 3: NF Model Using MORA Predictors and Random Effects\n",lab_cor_rando,"\n",rando_R2_lab)) +
            theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
                  axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))
  }

}

############################### Summary stats for Pearson's and Mult R-squared
summary(NF_cor)
summary(third_cor)
summary(rando_cor)

pearson_corr <- as.data.frame(cbind(NF_cor,third_cor,rando_cor))
#mult_R2 <- as.data.frame(cbind(NF_R2,third_R2))

boxplot(pearson_corr)
boxplot(mult_R2)

t.test(pearson_corr$NF_cor, pearson_corr$third_cor)
t.test(pearson_corr$third_cor, pearson_corr$rando_cor)
#t.test(mult_R2$NF_R2, mult_R2$third_R2)

#####################
#     PLots for talk
####################

lab_R2 <- mean(NF_cor)^2
lab_third_R2 <- mean(third_cor)^2
rando_R2_lab <- mean(rando_cor)^2

print(week_count_viz_NF + ggtitle(paste("Model 1: NF Model Using MORA Predictors\nPearson's: 0.60\nMultiple R-squared: 0.36")) +
        theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
              axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))

print(week_count_viz_third + ggtitle(paste("Model 2: NF Model with 1/3 MORA in-sample\nPearson's: 0.62\nMultiple R-squared: 0.38")) + 
        theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
              axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))

print(rando_plot + ggtitle(paste("Model 3: NF Model Using MORA Predictors and Random Effects\nPearson's: 0.80\nMultiple R-squared: 0.64")) +
        theme(plot.title = element_text(size=20, face="bold"), legend.key.size = unit(2, 'cm'), axis.text=element_text(size=15,face="bold"),
              axis.title=element_text(size=18,face="bold")) + xlab("Weekly Predictions (log)") + ylab("Weekly On-site Counts (log)"))
################################## qaqc by site

# mora_df <- select(mora_df,-c(weekmod.y))
# mora_df <- mora_df %>% rename(weekmod = weekmod.x)
mora_df$fit <- predict(weekly_rando_mod, mora_df)

today_breh <-Sys.Date()
#pdf("plots.pdf", onefile = TRUE)

for (i in unique(mora_df$siteid)) {

  siteid_v1 <- mora_df[mora_df$siteid == i, ]
  print(i)
  
  Modeled = ggplot(siteid_v1, aes(x=weekstart , y=expm1(fit))) + geom_line() +  
  geom_point(aes(y=weekly_viz), colour="red") +
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
  
  Onsite_Count = ggplot(siteid_v1, aes(x=weekstart , y=weekly_viz, colour="red")) + geom_line()+ 
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
  
  IUD = ggplot(siteid_v1, aes(x=weekstart , y=iud)) + geom_line()+ 
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
    
  AUD = ggplot(siteid_v1, aes(x=weekstart , y=aud)) + geom_line()+ 
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
    
  PUD = ggplot(siteid_v1, aes(x=weekstart , y=pud)) + geom_line()+ 
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
    
  TUD = ggplot(siteid_v1, aes(x=weekstart , y=tud)) + geom_line()+ 
  ggtitle(paste(first(siteid_v1$site_name))) + 
  theme(plot.title = element_text(size=18)) 
  
  qaqcfigs<-grid.arrange(Modeled, Onsite_Count, IUD, AUD, PUD, TUD, ncol  = 2)
  ggsave(file=(paste(first(siteid_v1$site_name), today_breh,".pdf")), qaqcfigs)
}
#dev.off()          

# Scatter plots
for (i in unique(mora_df$siteid)) {
  
  siteid_v1 <- mora_df[mora_df$siteid == i, ]
  print(i)
  
  Modeled = ggplot(siteid_v1, aes(x=weekstart , y=expm1(fit))) + geom_point() +  
    geom_point(aes(y=weekly_viz), colour="red") +
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  Onsite_Count = ggplot(siteid_v1, aes(x=weekstart , y=weekly_viz, colour="red")) + geom_point()+ 
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  IUD = ggplot(siteid_v1, aes(x=weekstart , y=iud)) + geom_point()+ 
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  AUD = ggplot(siteid_v1, aes(x=weekstart , y=aud)) + geom_point()+ 
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  PUD = ggplot(siteid_v1, aes(x=weekstart , y=pud)) + geom_point()+ 
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  TUD = ggplot(siteid_v1, aes(x=weekstart , y=tud)) + geom_point()+ 
    ggtitle(paste(first(siteid_v1$site_name))) + 
    theme(plot.title = element_text(size=18)) 
  
  qaqcfigs<-grid.arrange(Modeled, Onsite_Count, IUD, AUD, PUD, TUD, ncol  = 2)
  ggsave(file=(paste(first(siteid_v1$site_name), today_breh,".pdf")), qaqcfigs)
}

