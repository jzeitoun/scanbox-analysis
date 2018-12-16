import numpy as np
import tifffile as tif

import sys
import os

import loadmat as lmat

"""
Simple script to convert tif data into sbx for import into Pacu.
Both .tif and .mat must be present.

------
Usage:
    python tif_to_sbx.py filename.tif
"""

def main():
    filename = sys.argv[1]
    basename = os.path.splitext(filename)[0]

    raw_data = tif.imread(basename + '.tif')
    raw_meta = lmat.loadmat(basename + '.mat')

    depth, height, width = raw_data.shape
    framerate = raw_meta['capfreq']

    # Interleave the channels pixelwise and save as sbx
    channel_0 = raw_data[::2]
    channel_1 = raw_data[1::2]
    sbx_data = np.stack((channel_0.ravel(), channel_1.ravel()), axis=1).ravel()
    sbx_data = ~sbx_data # Necessary inversion for Pacu import
    sbx_data.tofile(basename + '_converted.sbx')

    # Create metadata and save
    sbx_meta = {'scanmode': 1, 'channels': 1} # Assumed data is always 2 channel
    sbx_meta['sz'] = np.array((height, width), dtype='uint16')
    sbx_meta['recordsPerBuffer'] = height
    sbx_meta['resfreq'] = framerate * height
    lmat.spio.savemat(basename + '_converted.mat', {'info': sbx_meta})

if __name__ == '__main__':
    main()
