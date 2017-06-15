import numpy as np
import matplotlib.pyplot as plt

from matplotlib import gridspec
from mpl_toolkits.axes_grid1 import make_axes_locatable

def replot(cell_id):
    data = np.load(cell_id + '_analysis.npy').tolist()
    sq_size = data['sq_size']
    title_size = 12
    
    # calculate y limits
    y_max = np.max([max(np.concatenate([w['on_df/f'] for w in data['white_traces']])),max(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
    y_min = np.min([min(np.concatenate([w['on_df/f'] for w in data['white_traces']])),min(np.concatenate([b['on_df/f'] for b in data['black_traces']]))])
           
    # calculate color scalebar
    colorscale_max = np.max([max(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),max(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
    #colorscale_min = np.min([min(np.concatenate([w['mean_trace'] for w in data['white_mean_traces']])),min(np.concatenate([b['mean_trace'] for b in data['black_mean_traces']]))])
    colorscale_min = 0
    
    # set up figure
    fig = plt.figure(cell_id)
    #gs0 = gridspec.GridSpec(2, 2) 
    gs0 = gridspec.GridSpec(2, 3) 
    gs00 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[0])
    gs01 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[1])
    gs02 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[2])
    gs03 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[3])
    gs04 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[4])
    gs05 = gridspec.GridSpecFromSubplotSpec(sq_size, sq_size, subplot_spec=gs0[5])
        
    ''' PLOT ON & OFF RESPONSES '''
    # plot on traces
    #plt.figure('\'White\' Response Traces')
    for w in data['white_traces']:
        plt.subplot(gs00[w['linear_position']-1])
        plt.ylim(y_min,y_max)
        plt.xticks([])
        plt.yticks([])
        plt.plot(w['on_df/f'],linewidth=.5,c='gray')
        
    # plot mean on traces
    for m in data['white_mean_traces']:
        plt.subplot(gs00[m['linear_position']-1])
        plt.plot(m['mean_trace'],linewidth=.5,c='red')
    
    # plot off traces
    #plt.figure('\'Black\' Response Traces')
    for b in data['black_traces']:
        #plt.subplot(gs02[b['linear_position']-1])
        plt.subplot(gs03[b['linear_position']-1])
        plt.ylim(y_min,y_max)
        plt.xticks([])
        plt.yticks([])
        plt.plot(b['on_df/f'],linewidth=.5,c='gray')
        
    # plot mean off traces
    for m in data['black_mean_traces']:
        #plt.subplot(gs02[m['linear_position']-1])
        plt.subplot(gs03[m['linear_position']-1])
        plt.plot(m['mean_trace'],linewidth=.5,c='blue') 
    
    # White Responses
    ax1 = plt.subplot(gs01[:,:]) 
    im1 = plt.imshow(data['white_pixel_map'],interpolation='none',cmap='Reds')
    plt.title('White Raw Pixel Map', size=title_size)
    divider1 = make_axes_locatable(ax1)
    cax1 = divider1.append_axes("right", size="5%", pad=0.05)
    plt.colorbar(im1, cax=cax1)
    plt.clim(colorscale_min,colorscale_max)
    ax2 = plt.subplot(gs02[:,:])
    im2 = plt.imshow(data['filtered_white_z_score_map'],interpolation='none',cmap='Reds')
    plt.title('White Z-Score Pixel Map', size=title_size)
    divider2 = make_axes_locatable(ax2)
    cax2 = divider2.append_axes("right", size="5%", pad=0.05)
    plt.colorbar(im2, cax=cax2)
    # Black Responses
    ax4 = plt.subplot(gs04[:,:]) 
    im4 = plt.imshow(data['black_pixel_map'],interpolation='none',cmap='Blues')
    plt.title('Black Raw Pixel Map', size=title_size)
    divider4 = make_axes_locatable(ax4)
    cax4 = divider4.append_axes("right", size="5%", pad=0.05)
    plt.colorbar(im4, cax=cax4)
    plt.clim(colorscale_min,colorscale_max)
    ax5 = plt.subplot(gs05[:,:]) 
    im5 = plt.imshow(data['filtered_black_z_score_map'],interpolation='none',cmap='Blues')
    plt.title('Black Z-Score Pixel Map', size=title_size)
    divider5 = make_axes_locatable(ax5)
    cax5 = divider5.append_axes("right", size="5%", pad=0.05)
    plt.colorbar(im5, cax=cax5)
    
    gs0.tight_layout(fig, pad=0.05)

def export_svg(fig_num=0):
    if fig_num:
        fig = plt.figure(fig_num)
    ROI = str(plt.get_figlabels()[0])
    plt.savefig(ROI + '_figure.svg',dpi=300)
