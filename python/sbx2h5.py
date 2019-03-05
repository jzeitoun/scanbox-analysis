import numpy as np
import h5py

import sys

from sbxmap import sbxmap

import h5builder as h5b
from ims_spec import SPEC

def main():
    """ Uses ims_spec to convert an sbx file into an Imaris (.ims) file. """

    sbx = sbxmap(sys.argv[1])
    ims = h5py.File(sbx.filename + '.ims', 'w')

    # Parse sbx data into TCZYX form.
    depth, height, width = sbx.shape
    mmap = np.memmap(
            'tempfile.mmap',
            dtype='uint16',
            shape=(depth, len(sbx.channels), sbx.num_planes, height, width),
            mode='w+'
            )

    for c, channel in enumerate(sbx.channels):
        for plane in range(sbx.num_planes):
            data = sbx.data()[channel]['plane_{}'.format(plane)]
            mmap[:, c, plane, ...] = data

    h5b.construct(ims, mmap, SPEC)

if __name__ == '__main__':
    main()



