import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import os

from pacu.core.io.scanbox.impl2 import ScanboxIO

from readSmoothWalkVelocity import findSmoothVelocity
from analyze_eye import analyze_eye

def find_relationship(io_file,_workspace):
    if '.io' in io_file:                                                       
        io_file = io_file[:-3]                                                 
    base_filename = io_file.split('_')[-3:]
    base_filename = '_'.join(base_filename)
    os.mkdir(io_file + '-analysis')                                            
    dir_path = os.path.abspath(io_file + '-analysis')                          
    path = os.getcwd()                                                         
    io = ScanboxIO(os.path.join(path,io_file + '.io'))                         
    workspace = [w for w in io.condition.workspaces if w.name == _workspace][0]
    conditions = [dict(t.attributes) for t in io.condition.trials]
    rois = [roi for roi in workspace.rois]
    framerate = io.condition.framerate
    number_frames = rois[0].dtorientationsmeans.first.on_frames
    orientations = np.array(io.condition.orientations)

    on_times = np.array([d['on_time'] for d in conditions])                                
    off_times = np.array([d['off_time'] for d in conditions])                              
                                                                                          
    on_frames = np.int64(on_times * framerate)                                              
    off_frames = np.int64(off_times * framerate)                                            
                                                                                          
    on_idx = zip(on_frames,on_frames+number_frames+1)                                       
    #off_idx = zip(off_frames,np.append(on_frames[1:],on_frames[-1] + min(np.diff(on_frames))))

    '''Not using velocity for now'''
    ## generate velocity data
    #smooth_data = findSmoothVelocity(smoothwalk_file)

    ## adjust to zero-indexing
    #smooth_data['Count'] = np.int64(smooth_data['Count'])-1

    ## ensure velocity values are positive
    #smooth_data['Velocity'] = np.abs(smooth_data['Velocity'])

    ## extract mean of velocity for on_frames
    #sorted_mean_velocity = [
    #        (on[0],
    #            np.mean(smooth_data.set_index('Count').loc[on[0]:on[1]-1]['Velocity'].as_matrix())
    #            ) for on in on_idx
    #        ]

    ## create dataframe from sorted_mean_velocities
    #sv_dataset = pd.DataFrame(sorted_mean_velocity,columns=['on_frame','Velocity'])
    
    # generate eye data
    area_1 = np.load(base_filename + '_eye1_pupil_area.npy')
    angular_rotation_1 = np.load(base_filename + '_eye1_angular_rotation.npy')
    area_2 = np.load(base_filename + '_eye2_pupil_area.npy') 
    angular_rotation_2 = np.load(base_filename + '_eye2_angular_rotation.npy')
    # mask nan values, which represent excluded frames
    area_1 = np.ma.masked_invalid(area_1)
    area_2 = np.ma.masked_invalid(area_2)

    import ipdb; ipdb.set_trace()

    # take derivative of angular rotations
    #angular_rotation_1[1:,0] = np.diff(angular_rotation_1[:,0])
    #angular_rotation_1[0,0] = np.nan
    #angular_rotation_1[1:,1] = np.diff(angular_rotation_1[:,1])
    #angular_rotation_1[0,1] = np.nan
    #angular_rotation_2[1:,0] = np.diff(angular_rotation_2[:,0])
    #angular_rotation_2[0,0] = np.nan
    #angular_rotation_2[1:,1] = np.diff(angular_rotation_2[:,1])
    #angular_rotation_2[0,1] = np.nan

    # extract mean eye metrics for all on_frames
    sorted_mean_eye_data = [
            (on[0],
                np.mean(area_1[on[0]:on[1]]),
                np.mean(area_2[on[0]:on[1]])#,
                #np.mean(angular_rotation_1[on[0]:on[1],0]),
                #np.mean(angular_rotation_1[on[0]:on[1],1]),
                #np.mean(angular_rotation_2[on[0]:on[1],0]),
                #np.mean(angular_rotation_2[on[0]:on[1],1])
                ) for on in on_idx
            ]

    # create dataframe from sorted_
    eye_dataset = pd.DataFrame(sorted_mean_eye_data,columns=[
        'on_frame',
        'Eye 1 Mean Pupil Area',
        'Eye 2 Mean Pupil Area'#,
        #'Eye 1 Horizontal AR',
        #'Eye 1 Vertical AR',
        #'Eye 2 Horizontal AR',
        #'Eye 2 Vertical AR'
        ])

    for roi in rois:
        roi.dtorientationbestprefs.first.refresh()
        pref_sf = roi.dtorientationbestprefs.first.attributes['peak_sf']
        pref_ori = roi.dtorientationbestprefs.first.attributes['value']
        pref_ori = orientations[np.where(np.abs(orientations-pref_ori) == np.min(np.abs(orientations-pref_ori)))]
        
        # find preferred sf/orientation trials
        pref_trials = roi.dttrialdff0s.filter_by(trial_ori = pref_ori,trial_sf = pref_sf)

        # get on_frames of preferred trials
        pref_on_frames = [int(trial.attributes['trial_on_time']*framerate) for trial in pref_trials]

        # creates tuples of on_frame and r-value 
        r_value = [
                (np.int64(trial.trial_on_time*framerate), 
                    np.mean(trial.value['on'])
                    )
                for trial in roi.dttrialdff0s
                ]

        # create dataframe from r-values
        dataset = pd.DataFrame(r_value,columns=['on_frame','r-value'])
        dataset['Pref r-value'] = dataset['r-value']
        dataset['Pref r-value'].loc[~dataset['on_frame'].isin(pref_on_frames)] = np.nan

        # add column for Rmax
        dataset['Rmax'] = np.nan
        peak_r_max = roi.dtorientationsfits.filter_by(trial_sf=pref_sf)[0]
        dataset['Rmax'][0] = peak_r_max.attributes['value']['r_max']
    
        # add column for anova each p at pref spatial freq
        dataset['Pref Anova Each P'] = np.nan
        dataset['Pref Anova Each P'][0] = roi.dtanovaeachs.filter_by(trial_sf=pref_sf)[0].p

        # add column for trial_sf and orientation
        dataset['trial_sf'] = [c['sf'] for c in conditions]
        dataset['trial_ori'] = [c['ori'] for c in conditions]

        # merge data into one dataset
        #dataset = pd.merge(dataset,sv_dataset,on='on_frame')
        dataset = pd.merge(dataset,eye_dataset,on='on_frame')

        # pickle data
        dataset.to_pickle(os.path.join(dir_path,str(roi.params.cell_id) + '_analysis.pickle'))
    #import ipdb; ipdb.set_trace()


