import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import pandas as pd
import os

from scipy.ndimage.filters import gaussian_filter

from pacu.core.io.scanbox.impl2 import ScanboxIO
from pacu.core.io.scanbox.impl2 import ExperimentV1

def sub2ind(array_shape, rows, cols):
    '''Converts xy coordinates to linear'''
    return (rows*array_shape[1]) + cols + 1
  
def get_receptive_field(io_file,_workspace, pixel_duration=None, trailing_seconds=2):
    #if '.io' in io_file:
    #    io_file = io_file[:-3]
    io_file = os.path.splitext(io_file)[0]
    name = io_file.split('_')
    basename = '_'.join(name[-3:])
    io_file = io_file + '.io'
    mouse_name = os.getcwd().split('/')[-2]
    #basename = [word for word in name if 'Aligned' not in word and 'Moco' not in word]
    #basename = '_'.join(basename)
    path = os.getcwd()
    ex = ExperimentV1()
    io = ScanboxIO(os.path.abspath(io_file))
    #io = ScanboxIO(os.path.join(path,io_file + '.io'))
    workspace = [w for w in io.condition.workspaces if w.name == _workspace][0]
    rois = [roi for roi in workspace.rois]
    os.mkdir(io_file + '-analysis')
    dir_path = os.path.abspath(io_file + '-analysis')
    framerate = io.condition.framerate
    trailing_frames = int(trailing_seconds * framerate)
    num_on_frames = int(io.condition.on_duration * framerate)
    num_off_frames = int(io.condition.off_duration * framerate)
    baseline_select = num_on_frames
    
    if pixel_duration == None:
        pixel_duration = num_on_frames
    else:
        pixel_duration = int(pixel_duration * framerate)

    for roi in rois:
        dtoverallmean = roi.dtoverallmean.value
        c_id = ex.find_keyword(mouse_name + '_' + basename)[0][0]
        # extract conditions from db
        conditions = ex.get_by_id(c_id).ordered_trials
        sq_size = max([c['y'] for c in conditions]) + 1
        num_positions = range(1,sq_size**2+1)
    
        on_times = np.array([c['on_time'] for c in conditions])
        #off_times = np.array([c['off_time'] for c in conditions])
        
        on_frames = np.int64(on_times * framerate)
        #off_frames = np.int64(off_times * framerate)
        
        on_idx = zip(on_frames,on_frames+trailing_frames)
        #off_idx = zip(off_frames,np.append(on_frames[1:],on_frame[-1] + min(np.diff(on_frame))))
        baseline_idx = zip(on_frames - baseline_select, on_frames)
        baseline_idx[0] = (baseline_idx[0][0],None)

        for c,d1,d2 in zip(conditions,on_idx,baseline_idx):
            linear_position = sub2ind([sq_size,sq_size],(sq_size - 1 - c['y']),c['x'])
            c.update(
                {'on_start_frame':d1[0],'on_end_frame':d1[1],
                'baseline_start_frame':d2[0],'baseline_end_frame':d2[1],
                'linear_position':linear_position}
                )
          
        # remove trials if not enough frames  
        if len(dtoverallmean) < conditions[-1]['on_end_frame']:
            max_idx = min([conditions.index(c) for c in conditions if c['on_end_frame'] > len(dtoverallmean)])
            conditions = conditions[:max_idx]
        
        # sort frames
        for c in conditions:
            c.update(
                {'on_frame_values':
                    dtoverallmean[c['on_start_frame']:c['on_end_frame']],
                'baseline_frame_values':
                    dtoverallmean[c['baseline_start_frame']:c['baseline_end_frame']]}
                )
        
        # calculate df/f    
        baseline = np.array([np.mean(c['baseline_frame_values']) for c in conditions])    
        #baseline = np.roll(baseline,1)
        
        for c,b in zip(conditions,baseline):
            c.update(
                {'on_df/f':(c['on_frame_values'] - b)/b,
                'baseline_value':b}
                )
        
        # calculate mean traces, segregated by color value
        white_traces = [c for c in conditions if c['v'] == 1]
        black_traces = [c for c in conditions if c['v'] == -1]    

        white_mean_traces = [dict(linear_position=r,v=1,mean_trace=np.array([])) for r in range(1,sq_size**2+1)]
        black_mean_traces = [dict(linear_position=r,v=1,mean_trace=np.array([])) for r in range(1,sq_size**2+1)]
        
        for m in white_mean_traces:
            m['mean_trace'] = np.mean([np.stack(w['on_df/f'],axis=0) for w in white_traces if w['linear_position'] == m['linear_position']],axis=0)
        for m in black_mean_traces:
            m['mean_trace'] = np.mean([np.stack(w['on_df/f'],axis=0) for w in black_traces if w['linear_position'] == m['linear_position']],axis=0)
       
        ''' MEAN PIXEL CALCULATION'''
        # calculate pixel maps from mean traces
        #white_pixel_map = np.array([np.max(k['mean_trace'][:num_on_frames]) for k in white_mean_traces]).reshape([sq_size,sq_size])
        #black_pixel_map = np.array([np.max(k['mean_trace'][:num_on_frames]) for k in black_mean_traces]).reshape([sq_size,sq_size])

        # uncomment to use sum instead of max
        white_pixel_map = np.array([np.sum(k['mean_trace'][:pixel_duration]) for k in white_mean_traces]).reshape([sq_size,sq_size])
        black_pixel_map = np.array([np.sum(k['mean_trace'][:pixel_duration]) for k in black_mean_traces]).reshape([sq_size,sq_size])

        # calculate z-score map
        white_z_score_map = (white_pixel_map - np.mean(white_pixel_map)) / np.std(white_pixel_map)
        black_z_score_map = (black_pixel_map - np.mean(black_pixel_map)) / np.std(black_pixel_map)

        filtered_white_z_score_map = gaussian_filter(white_z_score_map,sigma=1)
        filtered_black_z_score_map = gaussian_filter(black_z_score_map,sigma=1)
        
        # need to upscale by factor of 10 using cubic interpolation

        np.save(os.path.join(dir_path,roi.params.cell_id + '_analysis'),{'framerate':framerate,
                                   'sq_size':sq_size,
                                   'white_traces':white_traces,
                                   'black_traces':black_traces,
                                   'white_pixel_map':white_pixel_map,
                                   'black_pixel_map':black_pixel_map,
                                   'white_mean_traces':white_mean_traces,
                                   'black_mean_traces':black_mean_traces,
                                   'filtered_white_z_score_map':filtered_white_z_score_map,
                                   'filtered_black_z_score_map':filtered_black_z_score_map})

    #if plot:
    #    # calculate y limits
    #    y_max = np.max([max(np.concatenate([w['on_df/f'] for w in data['white_traces']])),max(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
    #    y_min = np.min([min(np.concatenate([w['on_df/f'] for w in data['white_traces']])),min(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
    #           
    #    # calculate color scalebar
    #    colorscale_max = np.max([max(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),max(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
    #    #colorscale_min = np.min([min(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),min(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
    #    colorscale_min = 0
    #    
    #    # set up figure
    #    fig = plt.figure(ROI)
    #    gs0 = gridspec.GridSpec(2, 2) 
    #    gs00 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[0])
    #    gs01 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[1])
    #    gs02 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[2])
    #    gs03 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[3])

    #    ''' PLOT ON & OFF RESPONSES '''
    #    # plot on traces
    #    #plt.figure('\'White\' Response Traces')
    #    for w in data['white_traces']:
    #        plt.subplot(gs00[w['linear_position']-1])
    #        plt.ylim(y_min,y_max)
    #        plt.xticks([])
    #        plt.yticks([])
    #        plt.plot(w['on_df/f'],linewidth=.5,c='gray')
    #        
    #    # plot mean on traces
    #    for m in data['white_mean_traces']:
    #        plt.subplot(gs00[m['linear_position']-1])
    #        plt.plot(m['mean_trace'],linewidth=.5,c='red')
    #    
    #    # plot off traces
    #    #plt.figure('\'Black\' Response Traces')
    #    for b in data['black_traces']:
    #        plt.subplot(gs02[b['linear_position']-1])
    #        plt.ylim(y_min,y_max)
    #        plt.xticks([])
    #        plt.yticks([])
    #        plt.plot(b['on_df/f'],linewidth=.5,c='gray')
    #        
    #    # plot mean off traces
    #    for m in data['black_mean_traces']:
    #        plt.subplot(gs02[m['linear_position']-1])
    #        plt.plot(m['mean_trace'],linewidth=.5,c='blue') 
    #    
    #    # display on and off pixel maps
    #    #plt.figure('\'White\' Response Pixel Map')
    #    plt.subplot(gs01[:,:]) 
    #    plt.imshow(data['white_pixel_map'],interpolation='none',cmap='Reds')
    #    plt.title('White Response Pixel Map')
    #    plt.clim(colorscale_min,colorscale_max)
    #    plt.colorbar()
    #    #plt.figure('\'Black\' Response Pixel Map')
    #    plt.subplot(gs03[:,:]) 
    #    plt.imshow(data['black_pixel_map'],interpolation='none',cmap='Blues')
    #    plt.title('Black Response Pixel Map')
    #    plt.clim(colorscale_min,colorscale_max)
    #    plt.colorbar()
    #    gs0.tight_layout(fig,pad=0.5)
                                   
#def replot(cell_id):
#    data = np.load(cell_id + '_analysis.npy').tolist()
#    sq_size = data['sq_size']
#    
#    # calculate y limits
#    y_max = np.max([max(np.concatenate([w['on_df/f'] for w in data['white_traces']])),max(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
#    y_min = np.min([min(np.concatenate([w['on_df/f'] for w in data['white_traces']])),min(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
#           
#    # calculate color scalebar
#    colorscale_max = np.max([max(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),max(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
#    #colorscale_min = np.min([min(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),min(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
#    colorscale_min = 0
#    
#    # set up figure
#    fig = plt.figure(ROI)
#    gs0 = gridspec.GridSpec(2, 2) 
#    gs00 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[0])
#    gs01 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[1])
#    gs02 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[2])
#    gs03 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[3])
#
#    '''PLOT ON & OFF RESPONSES'''
#    # plot on traces
#    for w in data['white_traces']:
#        plt.subplot(gs00[w['linear_position']-1])
#        plt.ylim(y_min,y_max)
#        plt.xticks([])
#        plt.yticks([])
#        plt.plot(w['on_df/f'],linewidth=.5,c='gray')
#        
#    # plot mean on traces
#    for m in data['white_mean_traces']:
#        plt.subplot(gs00[m['linear_position']-1])
#        plt.plot(m['mean_trace'],linewidth=.5,c='red')
#    
#    # plot off traces
#    for b in data['black_traces']:
#        plt.subplot(gs02[b['linear_position']-1])
#        plt.ylim(y_min,y_max)
#        plt.xticks([])
#        plt.yticks([])
#        plt.plot(b['on_df/f'],linewidth=.5,c='gray')
#        
#    # plot mean off traces
#    for m in data['black_mean_traces']:
#        plt.subplot(gs02[m['linear_position']-1])
#        plt.plot(m['mean_trace'],linewidth=.5,c='blue') 
#    
#    # display on and off pixel maps
#    plt.subplot(gs01[:,:]) 
#    plt.imshow(data['white_pixel_map'],interpolation='none',cmap='Reds')
#    plt.title('White Response Pixel Map')
#    plt.clim(colorscale_min,colorscale_max)
#    plt.colorbar()
#    plt.subplot(gs03[:,:]) 
#    plt.imshow(data['black_pixel_map'],interpolation='none',cmap='Blues')
#    plt.title('Black Response Pixel Map')
#    plt.clim(colorscale_min,colorscale_max)
#    plt.colorbar()
#    gs0.tight_layout(fig,pad=0.5)
#
#def export_svg(fig_num=0):
#    if fig_num:
#        fig = plt.figure(fig_num)
#    ROI = str(plt.get_figlabels()[0])
#    fig.savefig(ROI + '_figure.svg',dpi=300)
