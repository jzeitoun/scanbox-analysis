import os
import numpy as np
import scipy.io as spio
import tifffile as tif

def loadmat(filename):
    '''
    this function should be called instead of direct spio.loadmat
    as it cures the problem of not properly recovering python dictionaries
    from mat files. It calls the function check keys to cure all entries
    which are still mat-objects
    '''
    data = spio.loadmat(filename, struct_as_record=False, squeeze_me=True)
    return _check_keys(data)
    
def _check_keys(dict):
    '''
    checks if entries in dictionary are mat-objects. If yes
    todict is called to change them to nested dictionaries
    '''
    
    for key in dict:
        if isinstance(dict[key], spio.matlab.mio5_params.mat_struct):
            dict[key] = _todict(dict[key])
    return dict
    
def _todict(matobj):
    '''
    A recursive function which constructs from matobjects nested dictionaries
    '''
     
    dict = {}
    for strg in matobj._fieldnames:
        elem = matobj.__dict__[strg]
        if isinstance(elem, spio.matlab.mio5_params.mat_struct):
            dict[strg] = _todict(elem)
        else:
            dict[strg] = elem
    return dict
    
def sbxread(filename):
    '''
    Reads metadata file associated with 'filename'.
    'filename' should be full path excluding .sbx
    '''
    # Check if contains .sbx and if so just truncate
    if '.sbx' in filename:
        filename = filename[:-4]
    
    # Load info
    info = loadmat(filename + '.mat')['info']
   
    # fixes issue when using uint16 for memmapping
    info['sz'] = info['sz'].tolist()

    # Defining number of channels/size factor
    if info['channels'] == 1: # both PMTs
        info['nChan'] = 2; factor = 1
    elif info['channels'] == 2: # green PMT
        info['nChan'] = 1; factor = 2
    elif info['channels'] == 3: # red PMT
        info['nChan'] = 1; factor = 2
        
    if info['scanmode'] == 0:
        info['recordsPerBuffer'] = info['recordsPerBuffer']*2
     
    # Determine number of frames in whole file (removed '-1')
    info['length'] = int(os.path.getsize(filename + '.sbx')/info['recordsPerBuffer']/info['sz'][1]*factor/4)
    
    info['nSamples'] = info['sz'][1] * info['recordsPerBuffer'] * 2 * info['nChan']
     
    return info

def sbxmap(filename):
    '''
    Creates memory map to .sbx file.
    '''

    if '.sbx' in filename:
         filename = filename[:-4]
    
    info = sbxread(filename)

    if info['channels'] is not 1:
        mapped_data = np.memmap(filename + '.sbx',dtype='uint16',shape=(info['length'],info['sz'][0],info['sz'][1]))
        
        return mapped_data
    
    else:
        print 'Data contains 2 channels, will return 1 mapped object for each channel.'
        mapped_data = np.memmap(filename + '.sbx',dtype='uint16')
        green_data = mapped_data[::2].reshape(info['length'],info['sz'][0],info['sz'][1])
        red_data = mapped_data[1::2].reshape(info['length'],info['sz'][0],info['sz'][1])

        return green_data, red_data
