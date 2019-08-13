import numpy as np
import scipy.io as spio
import sys

from loadmat import loadmat
from sbxmap import sbxmap

def main(filename):
    sbx = sbxmap(filename)
    meta = loadmat(sbx.filename + '.mat')['info']
    try:
        meta.get('mesoscope').pop('roi_table')
    except:
        pass

    try:
        meta.pop('otparam')
    except:
        pass

    meta['resfreq'] = meta['resfreq'] / sbx.num_planes

    for plane in range(sbx.num_planes):
        output_basename = sbx.filename + '_plane_{}'.format(plane)
        channel_data = [{'channel': channel, 'data': sbx.data()[channel]['plane_{}'.format(plane)]} for channel in sbx.channels]
        spio.savemat(output_basename + '.mat', {'info': meta})
        raw_out = np.memmap(output_basename + '.sbx', dtype='uint16',
                shape=(len(channel_data)*channel_data[0]['data'].shape[0], channel_data[0]['data'].shape[1], channel_data[0]['data'].shape[2]), mode='w+')
        sbx_output = sbxmap(output_basename + '.sbx')
        for item in channel_data:
            sbx_output.data()[item['channel']]['plane_0'][:] = item['data']

if __name__ == '__main__':
    main(sys.argv[1])
