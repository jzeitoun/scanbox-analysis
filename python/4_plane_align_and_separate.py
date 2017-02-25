import numpy as np
import tifffile as tiff
import os
import tempfile
import shutil
import sys

from montage_moco import *
from sbxread import *

def align_and_separate(fname,w=15):
    
    info = sbxread(fname,0,1)
    
    data = np.memmap(fname + '.sbx', dtype='uint16', shape=(info['length'], info['sz'][0], info['sz'][1]))
    
    cropped_data_height = info['sz'][0]-40
    cropped_data_width = info['sz'][1]-100
    
    #montage_height = cropped_data_height*2+30
    #montage_width = cropped_data_width*2+30
    #montage_length = info['length']/4
    
    # create temporary folder
    folder = tempfile.mkdtemp()

    # align data and return as memmapped object
    plane1 = ('plane 1',data[::4,20:-20,100:])
    plane2 = ('plane 2',data[1::4,20:-20,100:])
    plane3 = ('plane 3',data[2::4,20:-20,100:])
    plane4 = ('plane 4',data[3::4,20:-20,100:])
    aligned_1 = align(plane1,folder,w)
    aligned_2 = align(plane2,folder,w)
    aligned_3 = align(plane3,folder,w)
    aligned_4 = align(plane4,folder,w)
    tiff.imsave(fname + '_plane_1.tif', aligned_1)
    tiff.imsave(fname + '_plane_2.tif', aligned_2)
    tiff.imsave(fname + '_plane_3.tif', aligned_3)
    tiff.imsave(fname + '_plane_4.tif', aligned_4)
    
    
    try:
        shutil.rmtree(folder)
    except:
                print("Failed to delete: " + folder)
                
if __name__ = '__main__':
    
    fname = sys.argv[1]
    
    align_and_separate(fname)
    
    sys.exit()
    
    