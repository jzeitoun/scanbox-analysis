import sys

from sbxread import *

def split_planes(filename):

    if 'sbx' in filename:
        filename = filename[:-4]

    info = sbxread(filename)
    spio_info = loadmat(filename + '.mat')
    nplanes = info['otparam'][2]
    spio_info['info']['resfreq'] = spio_info['info']['resfreq']/float(nplanes)
    spio_info['info']['otparam'][2] = 1
    
    data = sbxmap(filename)


    if len(data) > 1: # 2 channels
        green_data = data[0]
        red_data = data[1]
        
        print 'Allocating space for new files...'

        green_mapped_planes = [np.memmap(
                                  '{}_green_plane_{}.sbx'.format(filename,plane+1),
                                  dtype='uint16',
                                  shape=(len(green_data[plane::nplanes]), info['sz'][0], info['sz'][1]),
                                  mode='w+')
                                  for plane in range(nplanes)
                                  ]



        red_mapped_planes = [np.memmap(
                                '{}_red_plane_{}.sbx'.format(filename,plane+1),
                                dtype='uint16',
                                shape=(len(red_data[plane::nplanes]), info['sz'][0], info['sz'][1]),
                                mode='w+')
                                for plane in range(nplanes)
                                ]

        print 'Splitting planes...'

        for plane,mapped_plane in enumerate(green_mapped_planes):
            mapped_plane[:,:,:] = green_data[plane::nplanes]
            #spio_info['info']['length'] = len(green_data[plane::nplanes])
            spio_info['info']['channels'] = 2
            spio.savemat('{}_green_plane_{}.mat'.format(filename,plane+1),{'info':spio_info['info']})

        for plane,mapped_plane in enumerate(red_mapped_planes):
            mapped_plane[:,:,:] = red_data[plane::nplanes]
            #spio_info['info']['length'] = len(red_data[plane::nplanes])
            spio_info['info']['channels'] = 3
            spio.savemat('{}_red_plane_{}.mat'.format(filename,plane+1),{'info':spio_info['info']})


    else: # 1 channel
        print 'Allocating space for new files...'

        mapped_planes = [np.memmap(
                            '{}_plane_{}.sbx'.format(filename,plane+1),
                            dtype='uint16',
                            shape=(len(data[plane::nplanes]), info['sz'][0], info['sz'][1]),
                            mode='w+')
                            for plane in range(nplanes)
                            ]

        print 'Splitting planes...'

        for plane,mapped_plane in enumerate(mapped_planes):
            mapped_plane[:,:,:] = data[plane::nplanes]
            #spio_info['info']['length'] = len(data[plane::nplanes])
            spio.savemat('{}_plane{}.mat'.format(filename,plane+1),{'info':spio_info['info']})

if __name__ == '__main__':

    split_planes(sys.argv[1])

    print 'Finished.'
