import numpy as np
import matplotlib.pyplot as plt

from readSmoothWalkVelocity import findSmoothVelocity
from analyze_eye import analyze_eye

def find_relationship(io_file,_workspace,smoothwalk_file,eye1_data,eye2_data):
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

    for roi in rois:
        # creates tuples of on_frame and r_value 
        r_value = [
                (np.int64(trial.trial_on_time*framerate), 
                    np.mean(trial.value['on'])
                    )
                for trial in roi.dttrialdff0s
                ]
        dataset = pd.DataFrame(r_value,columns=['on_frame','r-value'])

        smooth_data = findSmoothVelocity(smoothwalk_file)

