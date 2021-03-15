# mora-people-mora-problems
Using geoteagged-social media and other Predictors as Proxies in Quantifying Visitation in Mount Rainier National Park 

### Introduction

The Western United States has seen historic growth in the last decade. This growth has translated into unequaled use of public lands for recreation, creating pressures on some of their most fragile ecosystems. One of those fragile ecosystems are alpine lakes which punctuate much of the high-elevation cryosphere and draw concentrated patronage from backcountry recreationists. These visitors have been leaving behind levels of human waste, specifically feces, that has outpaced in-place waste mitigation apparatus currently maintained by land managers. The two basic components required to begin understanding the level of this impact is identifying if there is a human-specific fecal contribution to alpine lakes and how many people are using these lakes. To help quantify the intensity of use in these remote locations a visitation model created by Spencer Wood in the Mount Baker-Snoqualmie National Forest (MBS) was tested on Mount Rainier National Park(MORA). This MBS model uses geotagged social media data, and other predictors, as a proxy for estimating visitation. Geotagged social media posts scraped from MORA were used in conjunction with the MBS model to predict visitation at specific sites around the park. The hope is to create a modeling tool for MORA and if successful, expand the model's predictive ability into other national parks

### Site Selection

Trail count data from MORA were selected on two primary conditions. Was (1) the trail one that allowed the infrared counter to all traffic, essentially out-and-back trails, and (2) was the data within the last six years (2015-2020). Polygons were drawn to reflect the areas that would capture all visitors logged by infrared counters. These polygons would then provide the boundaries for social media posts associated with counter data.

<img src="docs/sites.png" width=50% height=50%>

### Preliminary Results

The on-site counts and social media posts for MORA were then used to test the ability of a model, parameterized in Mount Baker-Snoqualmie National Forest (MBS) (Wood, et al. 2020), to predict visitation on the national park scale. Model 1 was created using MBS data and tested using only MORA data onsite counts and predictors, while model 2 was built using ⅓ insample data from MORA and tested with the other ⅔ MORA data (Tbl. 1). Model 1s performance was _____ with a _Pearson’s of X and an R-squared of X. Model 2 showed marked improvement with a Pearson’s of X and an R-squared of X. The next steps to help explain error will be the inclusion of an indicator variable to capture unknown categorical differences in between MBS and MORA and the addition of random effects creating a mixed effects model. The hope is to further develop this model into a tool capable of explaining 70% of the error in complement my work assessing the effects of human interactions with aquatic environments in remote locations.


