import numpy as np
import matplotlib.pyplot as plt
import os

def generate_heatmaps():
    # load data
    file_list = os.listdir(os.getcwd())

    raw_xy = np.concatenate([np.load(filename)[1] for filename in file_list if 'raw_xy_position' in filename])
    rows,cols = np.load(filename)[0]

    # find velocity in pixels/frame
    velocity_xy = raw_xy.copy()
    velocity_xy[1:,0] = np.diff(velocity_xy[:,0])
    velocity_xy[1:,1] = np.diff(velocity_xy[:,1])
    velocity_xy[0] = [0,0]
    high_count = len(velocity_xy[velocity_xy > 50])
    print 'High Count:', high_count
    velocity_xy[velocity_xy > 50] = 0

    # generate positional and velocity heat map
    position_heatmap = np.zeros([rows,cols],dtype='int64')
    velocity_heatmap = position_heatmap.copy()
    count = 0
    #for x,y in raw_xy:
    #    position_heatmap[rows-1-y,x] += 1
    #    count += 1

    for Vx,Vy in velocity_xy:
        velocity_heatmap[Vy + rows/2,Vx + cols/2] += 1
        count += 1

    print 'Velocity Counts:', count
    
    return velocity_heatmap
