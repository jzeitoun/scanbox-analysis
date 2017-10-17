import numpy as np
import tifffile as tiff
import os
import tempfile
import shutil

from montage_moco import *
from sbxread import *

def make_montage(fname,align=0,w=15):
    
    info = sbxread(fname,0,1)
    
    data = np.memmap(fname + '.sbx', dtype='uint16', shape=(info['length'], info['sz'][0], info['sz'][1]))
    
    cropped_data_height = info['sz'][0]-40
    cropped_data_width = info['sz'][1]-100
    
    montage_height = cropped_data_height*2+30
    montage_width = cropped_data_width*2+30
    montage_length = info['length']/4
    
    if align == 1:
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
		
		montage = np.memmap(fname + '_montage.sbx', dtype='uint16', mode='w+', shape=(montage_length,montage_height,montage_width))
		
		row_idx = [10,10+cropped_data_height,10+cropped_data_height+10,10+cropped_data_height+10+cropped_data_height]
		col_idx = [10,10+cropped_data_width,10+cropped_data_width+10,10+cropped_data_width+10+cropped_data_width]
		
		# upper left
		montage[:,row_idx[0]:row_idx[1],col_idx[0]:col_idx[1]] = aligned_1
		# upper right
		montage[:,row_idx[0]:row_idx[1],col_idx[2]:col_idx[3]] = aligned_2
		# bottom left
		montage[:,row_idx[2]:row_idx[3],col_idx[0]:col_idx[1]] = aligned_3
		# bottom right
		montage[:,row_idx[2]:row_idx[3],col_idx[2]:col_idx[3]] = aligned_4
		
		tiff.imsave(fname + '_montage.tif', montage[1:])
		
		try:
			shutil.rmtree(folder)
		except:
			print("Failed to delete: " + folder)
    else:
	    montage = np.memmap(fname + '_montage.sbx', dtype='uint16', mode='w+', shape=(montage_length,montage_height,montage_width))
		
	    row_idx = [10,10+cropped_data_height,10+cropped_data_height+10,10+cropped_data_height+10+cropped_data_height]
	    col_idx = [10,10+cropped_data_width,10+cropped_data_width+10,10+cropped_data_width+10+cropped_data_width]
		
		# upper leftsbx
	    montage[:,row_idx[0]:row_idx[1],col_idx[0]:col_idx[1]] = ~data[::4,20:-20,100:]
		# upper right
	    montage[:,row_idx[0]:row_idx[1],col_idx[2]:col_idx[3]] = ~data[1::4,20:-20,100:]
		# bottom left
	    montage[:,row_idx[2]:row_idx[3],col_idx[0]:col_idx[1]] = ~data[2::4,20:-20,100:]
		# bottom right
	    montage[:,row_idx[2]:row_idx[3],col_idx[2]:col_idx[3]] = ~data[3::4,20:-20,100:]
		
	    tiff.imsave(fname + '_montage.tif', montage[1:])