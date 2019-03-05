import numpy as np

import json

import sys
import os
import shutil

from sbxmap import sbxmap


''' This script only works for single or multichannel data, not for optotune. '''

def concatenate(sbx_list, sbx_output):
    sbx_lengths = []
    for i,sbx in enumerate(sbx_list):
        sbx_lengths.append({'filename': sbx.filename})
        for channel in sbx.channels:
            data = sbx.data()[channel]['plane_0']
            length, _, _ = data.shape
            sbx_lengths[i][channel] = length
            start_idx = np.sum(s[channel] for s in sbx_lengths[0 : i])
            sbx_output.data()[channel]['plane_0'][start_idx : start_idx + length] = data
    return sbx_lengths

def main():
    filenames = sys.argv[1:]
    output_filename = '_'.join(list(map(lambda x: x.split('.')[0], filenames)))
    output_size = np.sum([os.path.getsize(f)//2 for f in filenames])
    sbx_list = [sbxmap(f) for f in filenames]
    np.memmap(output_filename + '.sbx', dtype='uint16', shape=output_size, mode='w+')
    shutil.copy(sbx_list[0].filename + '.mat', output_filename + '.mat')
    sbx_output = sbxmap(output_filename + '.sbx')

    print('Concatenating files: {}'.format(', '.join(filenames)))

    sbx_lengths = concatenate(sbx_list, sbx_output)

    with open(output_filename + '.json', 'w') as f:
        json.dump(sbx_lengths, f)

if __name__ == '__main__':
    main()



