import numpy as np
import h5py
import tifffile as tif

import psutil
import sys

from sbxmap import sbxmap
from statusbar import Statusbar


def main():
    """ Converts sbx data to tif format that can be read by Imaris. """

    sbx = sbxmap(sys.argv[1])

    depth, height, width = sbx.shape
    if '--crop' in sys.argv:
        try:
            start, stop = sys.argv[3:]
            start, stop = int(start), int(stop)
        except: # only one index
            start = 0
            stop = int(sys.argv[3])
    else:
        start = 0
        stop = depth


    # Parse sbx data into TZCYX form.

    num_channels = len(sbx.channels)
    num_planes = sbx.num_planes

    print(
f'Data contains:\n\
  - {num_channels} channels\n\
  - {sbx.num_planes} planes\n'
    )

    mmap = tif.tifffile.memmap(
            sbx.filename + '_ims.tif',
            dtype='uint16',
            shape=(stop-start, num_planes, num_channels, height, width),
            imagej=True
            )

    status = Statusbar(num_channels * sbx.num_planes,
            title='Converting data to tiff format...',
            mem_monitor=True, mem_thresh=10)
    status.initialize()

    for c, channel in enumerate(sbx.channels):
        for plane in range(sbx.num_planes):
            data = sbx.data()[channel]['plane_{}'.format(plane)][start:stop]

            status.update(c*sbx.num_planes+plane)

            frame_diff = data.shape[0] - mmap.shape[0]
            if frame_diff:
                data = data[frame_diff:] # Crop extra frames

            mmap[:, plane, c, ...] = ~data

    print('\nFinished.')

if __name__ == '__main__':
    main()



