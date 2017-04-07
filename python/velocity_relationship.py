import numpy as np
import matplotlib.pyplot as plt

from readSmoothWalkVelocity import findSmoothVelocity
from analyze_eye import analyze_eye

def find_relationship(io_file,_workspace,smoothwalk_file):#,eye1_data,eye2_data):
    if '.io' in io_file:                                                       
        io_file = io_file[:-3]                                                 
    os.mkdir(io_file + '-analysis')                                            
    dir_path = os.path.abspath(io_file + '-analysis')                          
    path = os.getcwd()                                                         
    io = ScanboxIO(os.path.join(path,io_file + '.io'))                         
    workspace = [w for w in io.condition.workspaces if w.name == _workspace][0]
    conditions = [dict(t.attributes) for t in io.condition.trials]
    rois = [roi for roi in workspace.rois]
    framerate = io.condition.framerate
    number_frames = rois[0].dtorientationsmeans.first.on_frames

    on_times = np.array([d['on_time'] for d in conditions])                                
    off_times = np.array([d['off_time'] for d in conditions])                              
                                                                                          
    on_frames = np.int64(on_times * framerate)                                              
    off_frames = np.int64(off_times * framerate)                                            
                                                                                          
    on_idx = zip(on_frames,on_frames+number_frames+1)                                       
    #off_idx = zip(off_frames,np.append(on_frames[1:],on_frames[-1] + min(np.diff(on_frames))))

    for roi in rois:
        # creates tuples of on_frame and r-value 
        r_value = [
                (np.int64(trial.trial_on_time*framerate), 
                    np.mean(trial.value['on'])
                    )
                for trial in roi.dttrialdff0s
                ]
        # create dataframe from r-values
        dataset = pd.DataFrame(r_value,columns=['on_frame','r-value'])
        
        # generate velocity data
        smooth_data = findSmoothVelocity(smoothwalk_file)
        # adjust to zero-indexing
        smooth_data['Count'] = np.int64(smooth_data['Count'])-1
        # extract mean of velocity for on_frames
        sorted_mean_velocity = [
                (on[0],
                    np.mean(smooth_data.set_index('Count').loc[on[0]:on[1]-1]['Velocity'].as_matrix())
                    ) for on in on_idx
                ]
        # create dataframe from sorted_mean_velocities
        sv_dataset = pd.DataFrame(sorted_mean_velocity,columns=['on_frame','velocity'])
        
        # generate eye data
        #area_1, angular_rotation_1 = 
        
        # merge data into one dataset
        dataset = pd.merge(dataset,sv_dataset,on='on_frame')

        return dataset
