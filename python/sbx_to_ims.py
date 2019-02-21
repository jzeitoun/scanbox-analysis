import numpy as np
import h5py
import tifffile as tif

import tempfile
import psutil
import sys

from sbxmap import sbxmap
from statusbar import Statusbar

import h5builder as h5b
from ims_spec import SPEC


def main():
    """ Uses ims_spec to convert an sbx file into an Imaris (.ims) file. """

    sbx = sbxmap(sys.argv[1])
    ims = h5py.File(sbx.filename + '.ims', 'w')


    # Parse sbx data into TCZYX form.
    depth, height, width = sbx.shape

    num_channels = len(sbx.channels)
    num_planes = sbx.num_planes

    print(
'Data contains:\n\
    - {} channel{}\n\
    - {} planes\n'
    .format(num_channels, 's'*int(num_channels>1), num_planes)
    )

    #with tempfile.TemporaryFile() as tempfh:
    mmap = np.memmap(
            #tempfh,
            'tempfile.mmap',
            dtype='uint16',
            shape=(depth, num_planes, num_channels, height, width),
            mode='w+'
            )

    status = Statusbar(num_channels * num_planes,
            title='Preparing data for conversion...',
            mem_monitor=True, mem_thresh=10)
    status.initialize()

    for c, channel in enumerate(sbx.channels):
        for plane in range(sbx.num_planes):
            data = sbx.data()[channel]['plane_{}'.format(plane)]

            status.update(c*sbx.num_planes+plane)

            frame_diff = data.shape[0] - mmap.shape[0]
            if frame_diff:
                data = data[frame_diff:] # Crop extra frames

            mmap[:, plane, c, ...] = ~data

    h5b.construct(ims, mmap, SPEC)

    print('Finished.')

if __name__ == '__main__':
    main()



