import numpy as np

import json

import sys
import os
import shutil

from sbxmap import sbxmap


''' This script only works for single or multichannel data, not for optotune. '''

def split(sbx_input, sbx_lengths):
    channels = [k for k in sbx_lengths[0].keys() if k in ['green', 'red']]
    _, height, width = sbx_input.shape
    for i,s in enumerate(sbx_lengths):
        size = np.sum([s[channel] for channel in channels]) * height * width
        output_filename = 'moco_aligned_' + s['filename'] # Assuming data is aligned
        np.memmap(output_filename + '.sbx', dtype='uint16', shape=size, mode='w+')
        shutil.copy(sbx_input.filename + '.mat', output_filename + '.mat')
        sbx = sbxmap(output_filename)
        length = s[channel]
        start_idx = np.sum(s[channel] for s in sbx_lengths[0 : i])
        sbx.data()[channel]['plane_0'][:] = sbx_input.data()[channel]['plane_0'][start_idx : start_idx + length]

def main():
    sbx_filename = sys.argv[1]
    json_filename = sys.argv[2]
    with open(json_filename) as f:
        sbx_lengths = json.load(f)

    print('Splitting file: {}'.format(sbx_filename))

    split(sbxmap(sbx_filename), sbx_lengths)

if __name__ == '__main__':
    main()



