import numpy as np

import os
import shutil
import sys

from sbxmap import sbxmap

def shift(filename, num_frames):
    print('Shifting file {} by {} frames...'.format(filename, num_frames))
    sbx = sbxmap(filename)
    _, height, width = sbx.shape
    data = np.memmap(filename, dtype='uint16')
    num_channels = len(sbx.channels)
    num_pixels = int(os.path.getsize(filename)/2)
    extra_length = height*width*num_channels*sbx.num_planes*int(num_frames)

    import ipdb; ipdb.set_trace()

    output = np.memmap(sbx.filename + '_shifted_{}'.format(num_frames) + '.sbx', dtype='uint16', shape=(extra_length + num_pixels), mode='w+')
    output[extra_length:] = data

    shutil.copy(sbx.filename + '.mat', sbx.filename + '_shifted_{}'.format(num_frames) + '.mat')
    print('Done.')

def main():
    shift(sys.argv[1], sys.argv[2])

if __name__ == '__main__':
    main()
