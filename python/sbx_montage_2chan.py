import numpy as np
import tifffile as tiff

from sbxread import *

def make_montage_2chan(fname):
    
    info = sbxread(fname)
    
    data = sbxmap(fname)
    #np.memmap(fname + '.sbx', dtype='uint16')
    green_data = data[::2].reshape([info['length'],info['sz'][0],info['sz'][1]])
    red_data = data[1::2].reshape([info['length'],info['sz'][0],info['sz'][1]])
    
    cropped_data_height = info['sz'][0]-40
    cropped_data_width = info['sz'][1]-100
    
    montage_height = cropped_data_height*2+30
    montage_width = cropped_data_width*2+30
    montage_length = info['length']/4
    
    montage = np.memmap(fname + '_montage.sbx', dtype='uint8', mode='w+', shape=(montage_length,montage_height,montage_width,3))
    
    row_idx = [10,10+cropped_data_height,10+cropped_data_height+10,10+cropped_data_height+10+cropped_data_height]
    col_idx = [10,10+cropped_data_width,10+cropped_data_width+10,10+cropped_data_width+10+cropped_data_width]
    
    # upper left
    montage[:,row_idx[0]:row_idx[1],col_idx[0]:col_idx[1],:] = np.uint8(
                                                                   np.stack(
                                                                       [np.double(~red_data[::4,20:-20,100:])/65535*255,
                                                                       np.double(~green_data[::4,20:-20,100:])/65535*255,
                                                                       np.zeros([info['length']/4,cropped_data_height,cropped_data_width])],axis=0
                                                                   )
                                                               ).transpose(1,2,3,0)
    # upper right
    montage[:,row_idx[0]:row_idx[1],col_idx[2]:col_idx[3],:] = np.uint8(
                                                                   np.stack(
                                                                       [np.double(~red_data[1::4,20:-20,100:])/65535*255,
                                                                       np.double(~green_data[1::4,20:-20,100:])/65535*255,
                                                                       np.zeros([info['length']/4,cropped_data_height,cropped_data_width])],axis=0
                                                                   )
                                                               ).transpose(1,2,3,0)
    # bottom left
    montage[:,row_idx[2]:row_idx[3],col_idx[0]:col_idx[1],:] = np.uint8(
                                                                   np.stack(
                                                                       [np.double(~red_data[2::4,20:-20,100:])/65535*255,
                                                                       np.double(~green_data[2::4,20:-20,100:])/65535*255,
                                                                       np.zeros([info['length']/4,cropped_data_height,cropped_data_width])],axis=0
                                                                   )
                                                               ).transpose(1,2,3,0)
    # bottom right
    montage[:,row_idx[2]:row_idx[3],col_idx[2]:col_idx[3],:] = np.uint8(
                                                                   np.stack(
                                                                       [np.double(~red_data[3::4,20:-20,100:])/65535*255,
                                                                       np.double(~green_data[3::4,20:-20,100:])/65535*255,
                                                                       np.zeros([info['length']/4,cropped_data_height,cropped_data_width])],axis=0
                                                                   )
                                                               ).transpose(1,2,3,0)
    
    tiff.imsave(fname + '_montage.tif', montage[1:])
    
