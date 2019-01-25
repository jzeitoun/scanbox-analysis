import sys, glob, os
import tifffile as tif
import numpy as np
from sbxmap import sbxmap

def main():

    files = sorted(glob.glob("*.sbx"))
    upto = 0

    sbx_files = [sbxmap(f) for f in files]
    lengths = [sbx.shape[0] for sbx in sbx_files]
    combined_length = np.sum(lengths)
    time, height, width = sbx_files[0].shape

    mmap = np.memmap(
                    'tempfile.mmap',
                    dtype='uint16',
                    shape=(time, len(sbx.channels), sbx.num_planes, height, width),
                    mode='w+'
                    )

    for i, sbx in ennumerate(sbx_files):

        for c, channel in enumerate(sbx.channels):
            for plane in range(sbx.num_planes):
                data = sbx.data()[channel]['plane_{}'.format(plane)]

                mmap[upto:upto+lengths[i], c, plane, ...] = ~data

        upto = upto + lengths[i] + 1


    tif.imwrite(files[0][:-12]+'.tif',mmap,imagej=True)

if __name__ == '__main__':
    main()
    