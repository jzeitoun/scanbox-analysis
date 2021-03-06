import numpy as np
import pandas as pd
import scipy.io as sio
import os

def insert_all_data(df):
    # get list of all files
    all_files = [f for f in os.listdir(os.getcwd()) if os.path.isfile(f) and f[0] is not '.']
    # get mouse name
    mouse = os.getcwd().split('/')[-1]
    # extract filenames
    filenames = ['_'.join(f.split('_')[:4]) for f in all_files if 'pupil_area' in f]
    # add blank rows
    blank = [None for i in range(df.shape[1])]
    blank_series = pd.Series(blank, index=df.columns.tolist()) 
    for i in range(len(filenames)):
        df = df.append(blank_series, ignore_index=True)

    # determine available indexes
    idx_list = df[df['mouse'].isnull()].index.tolist()

    for filename in filenames:
        # get smallest available index
        idx = idx_list.pop(0)
        # insert data values
        df['mouse'][idx] = mouse
        df['recording'][idx] = filename
        df['eye'][idx] = 'ipsi' if 'eye1' in filename else 'contra'
        #try:
        #    df['stimulus_kwargs'][idx] = np.load(mouse + '_' + '_'.join(filename.split('_')[:-1]) + '.npy')[0]
        #    df['conditions'][idx] = np.load(mouse + '_' + '_'.join(filename.split('_')[:-1]) + '.npy')[1]
        #except IOError:
        #    df['stimulus_kwargs'][idx] = None
        #    df['conditions'][idx] = None
        #df['pupil_diameter'][idx] = convert_diam(df,idx,filename + '_pupil_area.npy')
        df['raw_xy'][idx] = np.load(filename + '_raw_xy_position.npy')[1]
        #df['velocity'][idx] = find_angular_velocity(df,idx,df['raw_xy'][idx])

    return df

def convert_diam(df, idx):
    pixels_per_mm = df['pixels_per_mm'][idx]
    filename = df['recording'][idx] + '_pupil_area.npy'
    pupil = np.load(filename)
    diameter = (2*np.sqrt(pupil/np.pi)/pixels_per_mm)
    df['pupil_diameter'][idx] = diameter

    #return diameter

def find_angular_velocity(df,idx):
    r_effective = 1.25
    pixels_per_mm = df['pixels_per_mm'][idx]
    velocity = np.diff(df['raw_xy'][idx], axis=0)
    ang_velocity = np.rad2deg(np.arcsin((velocity/pixels_per_mm)/r_effective))
    ang_velocity = np.insert(ang_velocity,0,np.nan,axis=0)
    df['velocity'][idx] = ang_velocity

    #return ang_velocity

def get_val(df,column,mouse,rec):
    series = df[(df['mouse'] == mouse) & (df['recording'] == rec)]
    return series[column][series.index[0]]

def sort_vector(df_,column,mouse,rec,fill=False,reverse=False):
    '''
    - "fill" determines whether to forward fill NaN values
    - "reverse" determines whether to sort the prior or post off period
    '''
    conditions = get_val(df_,'conditions',mouse,rec)
    if conditions != None:
        vector = get_val(df_,column,mouse,rec)
        # forward fill NaN values
        if fill == True:
            vector = pd.DataFrame(vector).fillna(method='ffill').as_matrix()
        stimulus_kwargs = get_val(df_,'stimulus_kwargs',mouse,rec)
        framerate = stimulus_kwargs['framerate']
        num_on_frames = int(framerate * stimulus_kwargs['on_duration'])
        num_off_frames = int(framerate * stimulus_kwargs['off_duration'])
        sfreqs = stimulus_kwargs['sfrequencies']
        oris = stimulus_kwargs['orientations']
        on_times = np.array([c['on_time'] for c in conditions])
        off_times = np.array([c['off_time'] for c in conditions])
        on_frames = np.int64(on_times * framerate)
        off_frames = np.int64(off_times * framerate)
        on_idx = zip(on_frames,on_frames + num_on_frames)
        off_idx = zip(off_frames,off_frames + num_off_frames)
        if reverse == True:
            off_idx = np.roll(off_idx,(1,1))

        for c,d1,d2 in zip(conditions,on_idx,off_idx):
            c.update(
                {'on_start_frame':d1[0],'on_end_frame':d1[1],
                'off_start_frame':d2[0],'off_end_frame':d2[1]}
                )
        # remove trials if not enough frames
        #if len(dtoverallmeans) < conditions[-1]['on_end_frame']:
        #    max_idx = min([conditions.index(c) for c in conditions if c['on_end_frame'] > len(dtoverallmeans)])
        #    conditions = conditions[:max_idx]
        # sort frames
        for c in conditions:
            c.update(
                {'on_frame_values':
                    vector[c['on_start_frame']:c['on_end_frame']],
                'off_frame_values':
                    vector[c['off_start_frame']:c['off_end_frame']]}
                )
        # conditions list now includes sorted vector
        return conditions

def find_sf_relationship(df,column,eye):
    '''- Finds the mean and std between the chosen column
       and sf.
       - Assumes conditions are the same across recordings.'''
    data = []
    for row in df.iterrows():
        if row[1]['eye'] == eye:
            mouse = row[1]['mouse']
            rec = row[1]['recording']
            sorted_column = sort_vector(db,column,mouse,rec)
            stimulus_kwargs = get_val(db,'stimulus_kwargs',mouse,rec)
            if stimulus_kwargs != None:
                sorted_list = {sf:[c['on_frame_values'] for c in sorted_column if c['sf'] == sf] for sf in stimulus_kwargs['sfrequencies']}
                data.append(sorted_list)

    data_stats = []
    for sf in stimulus_kwargs['sfrequencies']:
        val = np.concatenate([np.concatenate(c[sf]) for c in data])
        val = np.ma.masked_invalid(val)
        stats = {'sf':sf,'mean':np.ma.mean(val,axis=0),'std':np.ma.std(val,axis=0)}
        data_stats.append(stats)

    return data_stats, data

def export_sorted_mat(df,column,eye,filename):
    if '.mat' in filename:
        filename = filename[:-3]

    data = []
    for row in df.iterrows():
        if row[1]['eye'] == eye:
            mouse = row[1]['mouse']
            rec = row[1]['recording']
            sorted_column = sort_vector(df,column,mouse,rec,fill=True,reverse=True)
            stimulus_kwargs = get_val(df,'stimulus_kwargs',mouse,rec)
            if stimulus_kwargs != None:
                sorted_list = {'name':mouse + '_' + rec, 'data':[
                    {'sf':sf,'orientations':[
                        {'ori':ori,
                         'on_indices':None,
                         'off_indices':None,
                         'on_frame_values':None,
                         'off_frame_values':None}
                        for ori in stimulus_kwargs['orientations']
                        ]}
                    for sf in stimulus_kwargs['sfrequencies']
                    ]}
                for v in sorted_list['data']:
                    for k in v['orientations']:
                        k['off_frame_values'] = [c['off_frame_values'] for c in sorted_column if c['sf'] == v['sf'] and c['ori'] == k['ori']]
                        k['off_indices'] = ['{}:{}'.format(c['off_start_frame'],c['off_end_frame']) for c in sorted_column if c['sf'] == v['sf'] and c['ori'] == k['ori']] 

                for v in sorted_list['data']:
                    for k in v['orientations']:
                        k['on_frame_values'] = [c['on_frame_values'] for c in sorted_column if c['sf'] == v['sf'] and c['ori'] == k['ori']] 
                        k['on_indices'] = ['{}:{}'.format(c['on_start_frame'],c['on_end_frame']) for c in sorted_column if c['sf'] == v['sf'] and c['ori'] == k['ori']] 
                data.append(sorted_list)
    sio.savemat(filename + '_' + column + '.mat',{'dataset':data})
