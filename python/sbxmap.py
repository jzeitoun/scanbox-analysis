import numpy as np
import tifffile as tif
import multiprocessing
import os
import re

from statusbar import statusbar
from slicer import Slicer
import loadmat as lmat

class sbxmap(object):
    def __init__(self, filename):
        self.filename = os.path.splitext(filename)[0]
        self.num_planes = self.info['otparam'][2] if self.info['otparam'] != [] else 1

    @property
    def shape(self):
        if self.num_planes > 1:
            plane_length = len(
                               np.arange(self.info['length'])[::self.num_planes]
                               )
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
            return ['red']

    @property
    def data(self):
        if self.info['channels'] is not 1:
            mapped_data = np.memmap(self.filename + '.sbx', dtype='uint16',
                                    shape=(self.info['length'], self.info['sz'][0], self.info['sz'][1]))
            if self.num_planes > 1: # is data recorded with optotune?
                mapped_data = {'plane_{}'.format(i + 1): mapped_data[i::self.num_planes] for i in self.num_planes}
            return mapped_data

        else:
            mapped_data = np.memmap(self.filename + '.sbx', dtype='uint16')
            green_data = mapped_data[::2].reshape(self.info['length'], self.info['sz'][0], self.info['sz'][1])
            red_data = mapped_data[1::2].reshape(self.info['length'], self.info['sz'][0], self.info['sz'][1])
            if self.num_planes == 1: # is data recorded with optotune?
                return dict(green=green_data, red=red_data)
            else:
                green_multiplane = {'plane_{}'.format(i): green_data[i::self.num_planes] for i in range(self.num_planes)}
                red_multiplane = {'plane_{}'.format(i): red_data[i::self.num_planes] for i in range(self.num_planes)}
                return dict(green=green_multiplane, red=red_multiplane)

    def tifsave(self, length=None, rows=None, cols=None, basename=None, rgb=True):
        _depth = Slicer(self.shape[0]) if length == None else Slicer(*length)
        _rows = Slicer(self.shape[1]) if rows == None else Slicer(*rows)
        _cols = Slicer(self.shape[2]) if rows == None else Slicer(*cols)

        if _depth.length > self.shape[0] or _rows.length > self.shape[1] or _cols.length > self.shape[2]:
            raise ValueError('Cropped dimensions cannot be larger than original dimensions.')

        basename = self.filename if basename == None else os.path.splitext(basename)[0]
        num_cpu = multiprocessing.cpu_count()/2
        all_indices = np.arange(_depth.start,_depth.stop)
        idx_set = np.array_split(all_indices, num_cpu)
        if self.shape[0] < 100:
            status = statusbar(10)
        else:
            status = statusbar(50)

        if self.num_planes == 1: # single plane
            filenames = ['{}.tif'.format(basename)]
            if len(self.channels) > 1: # multichannel file
                if rgb == False: # split channels if RGB disabled
                    filenames = ['{}_{}.tif'.format(channel, basename)
                                 for channel in self.channels]
            else:
                rgb = False # single channel file

        else: # multiple planes
            filenames = ['{}_plane_{}.tif'.format(basename, i) for i in range(self.num_planes)]
            if len(self.channels) > 1: # multichannel file
                if rgb == False: # split channels if RGB disabled
                    filenames = ['{}_{}_plane_{}.tif'.format(channel, basename, i)
                                 for channel in self.channels
                                 for i in range(self.num_planes)]
            else:
                rgb = False # single channel file

        for filename in filenames: # create memory-mapped tiffs
            print 'Allocating space for tiff file: {}'.format(filename)
            tif.tifffile.memmap(filename,
                                shape=tuple([_depth.length, _rows.length, _cols.length] + {True:[3], False:[]}[rgb]),
                                dtype={True:'uint8', False:'uint16'}[rgb])

            params = [{'filename': filename,
                       'chunk_size': 100,
                       '_rows': _rows,
                       '_cols': _cols,
                       'indices': idx_subset}
                       for idx_subset in idx_set]
            params[-1].update({'status':status}) # use last process to update statusbar

            if self.num_planes == 1:
                pool = [multiprocessing.Process(target=self.singleplane_write, kwargs=p) for p in params]
            else:
                pool = [multiprocessing.Process(target=self.multiplane_write, kwargs=p) for p in params]

            print 'Starting {} processes...'.format(num_cpu)
            for process in pool:
                process.start()
            print 'Writing tiff...'
            status.run()
            for process in pool:
                process.terminate()
            print '\nDone.'

    def singleplane_write(self, filename=None, chunk_size=None, _rows=None, _cols=None, indices=None, status=None):
        tif_output = tif.tifffile.memmap(filename)
        dimensions = tif_output.shape
        depth, rows, cols = dimensions[:3]
        holder = np.zeros([chunk_size, rows, cols], dtype='uint16')
        if len(dimensions) == 4: # use RGB output
            for channel in self.channels:
                tif_input = self.data[channel]
                for i in indices:
                    if i % chunk_size == 0:
                        end = min(i + chunk_size, depth)
                        h_end = end - i
                        holder[:h_end] = 255 * (~tif_input[i:end, _rows.index, _cols.index] / 65535.0)
                        tif_output[i:end,:,:,{'green':1, 'red':0}[channel]] = holder[:h_end]
                    if status is not None:
                        status.broadcast(indices, i)
        else: # use grayscale
            if len(self.channels) > 1:
                channel = filename.split('_')[0]
            else:
                channel = slice(None)
            tif_input = self.data[channel]
            for i in indices:
                if i % chunk_size == 0:
                    end = min(i + chunk_size, depth)
                    h_end = end - i
                    holder[:h_end] = ~tif_input[i:end, _rows.index, _cols.index]
                    tif_output[i:end,:,:] = holder[:h_end]
                if status is not None:
                    status.broadcast(indices, i)


    def multiplane_write(self, filename=None, chunk_size=None, _rows=None, _cols=None, indices=None, status=None):
        tif_output = tif.tifffile.memmap(filename)
        plane = re.findall('plane_[0-9]{1}', filename)[0]
        dimensions = tif_output.shape
        depth, rows, cols = dimensions[:3]
        holder = np.zeros([chunk_size, rows, cols], dtype='uint16')
        if len(dimensions) == 4: # use RGB output
            for channel in self.channels:
                tif_input = self.data[channel][plane]
                for i in indices:
                    if i % chunk_size == 0:
                        end = min(i + chunk_size, depth)
                        h_end = end - i
                        holder[:h_end] = 255 * (~tif_input[i:end, _rows.index, _cols.index] / 65535.0)
                        tif_output[i:end,:,:,{'green':1, 'red':0}[channel]] = holder[:h_end]
                    if status is not None:
                        status.broadcast(indices, i)
        else: # use grayscale
            if len(self.channels) > 1:
                channel = filename.split('_')[0]
            else:
                channel = slice(None)
            tif_input = self.data[channel][plane]
            for i in indices:
                if i % chunk_size == 0:
                    end = min(i + chunk_size, depth)
                    h_end = end - i
                    holder[:h_end] = ~tif_input[i:end, _rows.index, _cols.index]
                    tif_output[i:end,:,:] = holder[:h_end]
                if status is not None:
                    status.broadcast(indices, i)

