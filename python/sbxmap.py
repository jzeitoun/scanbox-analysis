import numpy as np
import tifffile as tif
import multiprocessing
import os
import shutil
import re

from statusbar import statusbar
from slicer import Slicer
import loadmat as lmat

class sbxmap(object):
    def __init__(self, filename):
        self.filename = os.path.splitext(filename)[0]

    @property
    def num_planes(self):
        if 'otparam' in self.info:
            return self.info['otparam'][2] if self.info['otparam'] != [] else 1
        else:
            return 1
    @property
    def shape(self):
        if self.num_planes > 1:
            plane_length = len(np.arange(self.info['length'])[::self.num_planes])
            return (plane_length, self.info['sz'][0], self.info['sz'][1])
        else:
            return (self.info['length'], self.info['sz'][0], self.info['sz'][1])
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
        _info['length'] = int(
                os.path.getsize(self.filename + '.sbx')
                / _info['recordsPerBuffer']
                / _info['sz'][1]
                * factor
                / 4
                )
        _info['nSamples'] = _info['sz'][1] * _info['recordsPerBuffer'] * 2 * _info['nChan']
        return _info
    @property
    def channels(self):
        if self.info['channels'] == 1:
            return ['green', 'red']
        elif self.info['channels'] == 2:
            return ['green']
        elif self.info['channels'] == 3:
            return ['red']

    def data(self, length=[None], rows=[None], cols=[None]):
        fullshape = [self.info['length']] + self.info['sz']
        mapped_data = np.memmap(self.filename + '.sbx', dtype='uint16')
        data = {}
        for i,channel in enumerate(self.channels):
            data.update(
                    {channel : mapped_data[i::len(self.channels)].reshape(fullshape)}
                    )
            data[channel] = {
                    'plane_{}'.format(i) :
                        data[channel][i::self.num_planes][slice(*length), slice(*rows), slice(*cols)]
                    for i in range(self.num_planes)
                    }
        return data

    def crop(self, length=[None], rows=[None], cols=[None], basename=None):
        basename = self.filename if basename is None else os.path.splitext(basename)[0]
        cropped_data = self.data(length=length, rows=rows, cols=cols)
        size = []
        for channel, planes in cropped_data.items():
            for plane, data in planes.items():
                size.append(np.prod(data.shape))
        size = np.sum(size)
        output_memmap = np.memmap('{}_cropped.sbx'.format(basename),
                                  dtype='uint16',
                                  shape=size,
                                  mode='w+'
                                  )
        spio_info = lmat.loadmat(self.filename + '.mat')
        spio_info['info']['sz'] = data.shape[1:]
        if rows is not [None]: # rows were cropped, update recordsPerBuffer
            spio_info['info']['originalRecordsPerBuffer'] = spio_info['info']['recordsPerBuffer'];
            spio_info['info']['recordsPerBuffer'] = spio_info['info']['sz'][0]
        lmat.spio.savemat('{}_cropped.mat'.format(basename), {'info':spio_info['info']})
        input_data = sbxmap('{}_cropped.sbx'.format(basename))
        for channel,channel_data in input_data.data().items():
            for plane,plane_data in channel_data.items():
                plane_data[:] = cropped_data[channel][plane]

    def tifsave(self, length=None, rows=None, cols=None, basename=None, rgb=True):
        _depth = Slicer(self.shape[0]) if length == None else Slicer(*length)
        _rows = Slicer(self.shape[1]) if rows == None else Slicer(*rows)
        _cols = Slicer(self.shape[2]) if rows == None else Slicer(*cols)

        if _depth.length > self.shape[0] or _rows.length > self.shape[1] or _cols.length > self.shape[2]:
            raise ValueError('Cropped dimensions cannot be larger than original dimensions.')

        basename = self.filename if basename == None else os.path.splitext(basename)[0]
        num_cpu = multiprocessing.cpu_count()
        all_indices = np.arange(_depth.start,_depth.stop)
        num_tasks = len(all_indices) / 10
        idx_set = np.array_split(all_indices, num_tasks)

        # generate filenames
        if self.num_planes == 1: # single plane
            filenames = ['{}.tif'.format(basename)]
            if len(self.channels) > 1: # multichannel file
                if rgb == False: # split channels if RGB disabled
                    filenames = ['{}_{}.tif'.format(basename, channel)
                                 for channel in self.channels]
            else:
                rgb = False # single channel file

        else: # multiple planes
            filenames = ['{}_plane_{}.tif'.format(basename, i) for i in range(self.num_planes)]
            if len(self.channels) > 1: # multichannel file
                if rgb == False: # split channels if RGB disabled
                    filenames = ['{}_{}_plane_{}.tif'.format(basename, channel, i)
                                 for channel in self.channels
                                 for i in range(self.num_planes)]
            else:
                rgb = False # single channel file

        for filename in filenames: # create memory-mapped tiffs
            print('Allocating space for tiff file: {}'.format(filename))
            tif.tifffile.memmap(filename,
                                shape=tuple([_depth.length, _rows.length, _cols.length] + {True:[3], False:[]}[rgb]),
                                dtype={True:'uint8', False:'uint16'}[rgb])
            params = [
                       [write,
                         {'sbx': self,
                          'filename': filename,
                          '_rows': _rows,
                          '_cols': _cols,
                          'indices': idx_subset}
                       ]
                     for idx_subset in idx_set]

            # write tiffs to file
            status = statusbar(num_tasks)
            print('Starting {} processes...'.format(num_cpu))
            pool = multiprocessing.Pool(num_cpu)
            print('Writing tiff...')
            status.initialize()
            for i,_ in enumerate(pool.imap_unordered(kwargs_wrapper, params), 1):
                status.update(i)
            print('\nDone.')

def kwargs_wrapper(kwargs):
    function, kwargs = kwargs
    function(**kwargs)

def write(sbx, filename=None, _rows=None, _cols=None, indices=None):
    tif_output = tif.tifffile.memmap(filename)
    if 'plane' in filename:
        plane = re.findall('plane_[0-9]{1}', filename)[0]
    else:
        plane = 'plane_0'
    dimensions = tif_output.shape
    if len(dimensions) == 4: # use RGB output
        for channel in sbx.channels:
            tif_input = sbx.data()[channel][plane]
            for i in indices:
                frame = 255 * (~tif_input[i, _rows.index, _cols.index] / 65535.0)
                tif_output[i,:,:,{'green':1, 'red':0}[channel]] = frame
    else: # use grayscale
        if len(sbx.channels) > 1:
            channel = filename.split('_')[4]
        else:
            channel = sbx.channels[0]
        tif_input = sbx.data()[channel][plane]
        for i in indices:
            tif_output[i] = ~tif_input[i]

