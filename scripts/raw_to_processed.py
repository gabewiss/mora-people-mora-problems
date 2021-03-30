#!/usr/bin/env python

"""This script processes raw, hourly count data files
and turns them into a daily-count file
and a weekly-count file"""

import glob
import numpy as np
import os
import pandas as pd

#  import 'lookup_table' and set index
lookup_table = pd.read_csv('../tables/lookup_table.csv')
lookup_table = lookup_table.set_index('loc')

#  import exclusion.csv
exclusion_table = pd.read_csv('../tables/exclusion.csv', encoding='utf8')
exclusion_table['start'] = pd.to_datetime(exclusion_table['start'])
exclusion_table['stop'] = pd.to_datetime(exclusion_table['stop'])

#  process those two sites that had A and B counts for the same year
eagle_a = pd.read_csv('../data/raw_A_B_duplicates/Eagle Peak A 2011 RAW.csv',
                      names=['date', 'people_count'])
eagle_b = pd.read_csv('../data/raw_A_B_duplicates/Eagle Peak A 2011 RAW.csv',
                      names=['date', 'people_count'])
rampart_a = pd.read_csv('../data/raw_A_B_duplicates/Rampart Ridge A 2011 RAW.csv',
                      names=['date', 'people_count'])
rampart_b = pd.read_csv('../data/raw_A_B_duplicates/Rampart Ridge B 2011 RAW.csv',
                      names=['date', 'people_count'])

eagle_a['date'] = pd.to_datetime(eagle_a['date'])
eagle_a = eagle_a.resample('D', on='date').sum()
eagle_a.reset_index(level=0, inplace=True)

eagle_b['date'] = pd.to_datetime(eagle_b['date'])
eagle_b = eagle_b.resample('D', on='date').sum()
eagle_b.reset_index(level=0, inplace=True)

rampart_a['date'] = pd.to_datetime(rampart_a['date'])
rampart_a = rampart_a.resample('D', on='date').sum()
rampart_a.reset_index(level=0, inplace=True)

rampart_b['date'] = pd.to_datetime(rampart_b['date'])
rampart_b = rampart_b.resample('D', on='date').sum()
rampart_b.reset_index(level=0, inplace=True)

# combining the two raw count files for Eagle peak
eagle_combined = pd.concat([eagle_a, eagle_b], ignore_index=True)
eagle_combined = eagle_combined.groupby('date').mean()
eagle_combined.reset_index(level=0, inplace=True)

# combining the two raw count files for Eagle peak
rampart_combined = pd.concat([rampart_a, rampart_b], ignore_index=True)
rampart_combined = rampart_combined.groupby('date').mean()
rampart_combined.reset_index(level=0, inplace=True)

# add 'siteid', 'year', and 'adjusted count' columns
eagle_combined['siteid'] = lookup_table.loc['Eagle Peak A 2011 RAW.csv']
['siteid']
eagle_combined['adjusted_people_count'] = (eagle_combined['people_count'] *
                                           (lookup_table.loc['Eagle Peak '
                                            'A 2011 RAW.csv']
                                            ['adjustment_factor'])) / 2

rampart_combined['siteid'] = lookup_table.loc['Rampart Ridge A 2011 RAW.csv']
['siteid']
rampart_combined['adjusted_people_count'] = (rampart_combined['people_count'] *
                                             (lookup_table.loc['Rampart Ridge '
                                              'A 2011 RAW.csv']
                                              ['adjustment_factor'])) / 2

A_B_combined = pd.concat([eagle_combined, rampart_combined],
                         ignore_index=True)


# create empty pd.DataFrame for appending
raw_concat = pd.DataFrame([])

# loop for pulling raw count files, adding specific columns and
# adding to larger spreadsheet
for filepath in glob.glob('data/raw/*.{}'.format('csv')):

    # use filename to read csv into 'temp variable'
    temp = pd.read_csv(filepath, names=['date', 'people_count'])

    # make a filename from the filepath
    filename = filepath.split('/')[-1]

    # resample before adding new columns
    temp['date'] = pd.to_datetime(temp['date'])
    temp = temp.resample('D', on='date').sum()
    temp.reset_index(level=0, inplace=True)

    # put 'siteid' for specific file into variables
    temp['siteid'] = lookup_table.loc[filename]['siteid']

    # temp['year'] = lookup_table.loc[filename]['year']
    temp['adjusted_people_count'] = (temp['people_count'] *
                                     (lookup_table.loc[filename]
                                     ['adjustment_factor'])) / 2

    raw_concat = raw_concat.append(temp, ignore_index=True)

# concat the Eagle Peak A and B mean and the Rampart
# Ridge A and B mean to the raw_concat for daily visitation
raw_concat = pd.concat([raw_concat, A_B_combined], ignore_index=True)

# drop duplicates
raw_concat.drop_duplicates(subset=['date', 'siteid'], inplace=True,
                           ignore_index=False)

# chenge to datetime index and exclude nov-april
raw_concat['date'] = pd.to_datetime(raw_concat['date'])
# raw_concat.set_index(['date'], inplace=True)
raw_concat_excld_nov_to_apr = raw_concat[(raw_concat.date.dt.month > 4) &
                                         (raw_concat.date.dt.month < 11)]

# empty dataframes for looping
raw_concat_final_exclusion = pd.DataFrame([])
exclusion = pd.DataFrame([])
drop_me = ([])

for siteid in exclusion_table.siteid.unique():

    # create a boolean index for both raw_concat_excld_nov_to_apr and
    # exclusion_table based on siteid
    exclusion = raw_concat_excld_nov_to_apr[raw_concat_excld_nov_to_apr.siteid
                                            == siteid]
    baby_table = exclusion_table[exclusion_table.siteid == siteid]

    # print("Running site", str(siteid))
    exclusion_len = len(exclusion)

    for row in baby_table.itertuples():
        # unpack tuple containing row elements
        index, siteid, start, stop = row

        # drop rows between 'start' and 'stop' dates
        drop_me = exclusion[(exclusion.date.dt.date >= start) &
                            (exclusion.date.dt.date <= stop)].index
        exclusion = exclusion.drop(index=drop_me[0:])

    raw_concat_final_exclusion = raw_concat_final_exclusion.append(exclusion,
                                                                   ignore_index# noqa
                                                                   =False)

#  include sites that didn't have any excluded dates
exclude_siteids = exclusion_table.siteid.unique().tolist()
rawcon_siteids = raw_concat.siteid.unique().tolist()
need_to_add_to_final = [x for x in rawcon_siteids if x not in exclude_siteids]

to_append = raw_concat[raw_concat.siteid.isin(need_to_add_to_final)]
raw_concat_final_exclusion = raw_concat_final_exclusion.append(to_append,
                                                               ignore_index# noqa
                                                               =False)

# export daily counts
raw_concat_final_exclusion.to_csv('../data/processed/day_counts.csv', index=False)

# declaring df for appending in line 179
weekly = pd.DataFrame([])

# loop to create weekly spreadsheet from daily spreadsheet
for siteid in raw_concat_final_exclusion.siteid.unique():
    resample_siteid = pd.DataFrame([])

    # filter by 'siteid'
    resample_siteid = raw_concat_final_exclusion[raw_concat_final_exclusion.siteid == siteid]

    for year in resample_siteid.date.dt.year.unique():
        print('Processing site %i year %i'%(siteid, year))

        year_filter = resample_siteid[resample_siteid.date.dt.year == year].copy()

        # add column to count days of observations in the week
        year_filter['daycount'] = 1

        # resample by week
        year_filter = year_filter.resample('W-THU', label='left', on='date',
                                           closed='left').agg({'people_count':
                                                               'sum',
                                                               'adjusted_'
                                                               'people_count':
                                                               'sum',
                                                               'daycount'# noqa
                                                               : 'size'})

        # reset 'siteid'
        year_filter['siteid'] = siteid

        # reset index
        year_filter.reset_index(level=0, inplace=True)

        # add week of year column
        year_filter['weekmod'] = year_filter['date'].dt.isocalendar().week

        # relabel
        year_filter = year_filter.rename(columns={'date': 'weekstart',
                                                  'people_count':
                                                  'weekly_viz_raw',
                                                  'adjusted_people_count':
                                                  'weekly_viz'})

        # reindex
        year_filter = year_filter.reindex(columns=['weekmod', 'siteid',
                                                   'weekstart', 'weekly_viz',
                                                   'weekly_viz_raw',
                                                   'daycount'])

        # append for new weekly list
        weekly = weekly.append(year_filter, ignore_index=True)

# replace 0's with NaN
weekly['weekly_viz'] = weekly['weekly_viz'].replace(0, np.nan)
weekly['weekly_viz_raw'] = weekly['weekly_viz_raw'].replace(0, np.nan)

# removing nov-april
weekly['weekstart'] = pd.to_datetime(weekly['weekstart'])
weekly.set_index(['weekstart'], inplace=True)
weekly = weekly[(weekly.index.month > 4) & (weekly.index.month < 11)]
weekly = weekly[(weekly['daycount'] > 6)]
weekly = weekly.drop(columns=['daycount'])
weekly.reset_index(level=0, inplace=True)

# export
weekly.to_csv('../data/processed/weekly_counts.csv', index=False)
