import os
import numpy as np
import tifffile as tif

from Slicerr import Slicer
import loadmat as lmat

'''
TODO: Create efficient RGB conversion option. (Memory-mapping doesn't help because
      the entire array needs to be converted to 8 bit.)
'''
class sbxmap(object):
    def __init__(self, filename):
        self.filename = os.path.splitext(filename)[0]
        self.shape = (self.info['length'], self.info['sz'][0], self.info['sz'][1])

    @property
    def info(self):
        _info = lmat.loadmat(self.filename + '.mat')['info']

        # Fixes issue when using uint16 for memmapping
        _info['sz'] = _info['sz'].tolist()

        # Defining number of channels/size factor
        if _info['channels'] == 1:
            _info['nChan'] = 2; factor = 1
        elif _info['channels'] == 2:
            _info['nChan'] = 1; factor = 2
        elif _info['channels'] == 3:
            _info['nChan'] = 1; factor = 2

        if _info['scanmode'] == 0:
            _info['recordsPerBuffer'] = _info['recordsPerBuffer']*2

        # Determine number of frames in whole file
        _info['length'] = int(os.path.getsize(self.filename + '.sbx') / _info['recordsPerBuffer'] / _info['sz'][1] * factor / 4)
        _info['nSamples'] = _info['sz'][1] * _info['recordsPerBuffer'] * 2 * _info['nChan']
        return _info

    @property
    def channels(self):
        if self.info['channels'] == 1:
            return ['green', 'red']
        elif self.info['channels'] == 2:
            return ['green']
        elif self.info['channels'] == 3:
            return ['red]'

    @property
    def data(self):
        if self.info['channels'] is not 1:
            mapped_data = np.memmap(self.filename + '.sbx', dtype='uint16',
                                    shape=(self.shape))
            return mapped_data
        else:
            mapped_data = np.memmap(self.filename + '.sbx', dtype='uint16')
            green_data = mapped_data[::2].reshape(self.shape)
            red_data = mapped_data[1::2].reshape(self.shape)
            return green_data, red_data

    def gray_tifsave(self, length=None, rows=None, cols=None, output=None):

        if type(_depth) and type(_rows) and type(_cols) is not list or tuple:
            raise ValueError('All dimensions must be a list or tuple.')

        if output == None:
            _output = self.filename + '.tif'
        else:
            _output = os.path.splitext(output)[0]


    def tifsave(self, length=None, rows=None, cols=None, output=None, rgb=False):
        _depth = Slicer(self.shape[0]) if length == None else Slicer(*length)
        _rows = Slicer(self.shape[1]) if rows == None else Slicer(*rows)
        _cols = Slicer(self.shape[2]) if rows == None else Slicer(*cols)
        _output = self.filename if output == None else os.path.splitext(output)[0]

        all_idx = np.arange(self.shape[0])
        idx_set = np.array_split(all_idx, num_cpu)

        if rgb == False:
            tif_out = tif.tifffile.memmap('{}.tif'.format(_output),
                                    shape=(_depth.length, _rows.length, _cols.length, 3),
                                    dtype='uint8')
            params = [{'filename': tif_out.filename,
                      'chunk_size': 100,
                      'indices': idx}
                      for idx in idx_set]
            pool.map(self.rgb_write, params)
        else:
            filenames = ['{}_{}.tif'.format(channel,_output) for channel in self.channels]
            if len(filenames) == 1:
                filenames = ['{}.tif'.format(_output)]
            for filename in filenames:
                params = [{'filename': filename
                           'chunk_size': 100,
                           'indices': idx}
                           for idx in idx_set]
                pool.map(self.gray_write, params)

    def gray_write(self, params):
        _in = self.data
        _out = tif.tifffile.memmap(params['filename'])
        chunk_size = params['chunk_size']
        dims = _out.shape
        holder = np.zeros([chunk_size, rows, cols], dtype=_in.dtype)
        for channel in self.channels:
            for i in params['indices']:
                if i % chunk_size == 0:
                    end = min(i + chunk_size, depth)
                    h_end = end - i
                    holder[:h_end] = ~_in[i:end]
                    _out[i:end,:,:] = holder[:h_end]

    def rgb_write(self, params):
        rgb = {'green': 1, 'red': 0}
        _in = self.data
        _out = tif.tifffile.memmap(params['filename'])
        chunk_size = params['chunk_size']
        dims = _out.shape
        holder = np.zeros([chunk_size, rows, cols], dtype=_in.dtype)
        for channel in self.channels:
            for i in params['indices']:
                if i % chunk_size == 0:
                    end = min(i + chunk_size, depth)
                    h_end = end - i
                    holder[:h_end] = np.uint8(255 * (~_in[i:end] / 65535.0))
                    _out[i:end,:,:,rgb[channel]] = holder[:h_end]
