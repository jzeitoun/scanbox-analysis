import numpy as np
import scipy.io as spio
import multiprocessing
import time
import re
import os
import sys
import tempfile

from setproctitle import setproctitle
import moco_v2
import loadmat as lmat
from sbxmap import sbxmap
from statusbar import Statusbar

import globe

#TODO: Correct visualization

channel_options = ['green', 'red']
channel_lookup = {'green': 2, 'red': 3}

def generate_output(sbx, split_chan=False, split_planes=True):
    '''
    Generates set of memory-mapped files and the corresponding meta (.mat) files
    to hold the aligned output. If data is to be separated during alignment,
    separated files are reconstructed into dictionary layout that matches source
    data layout (sbx.data()).

    Returns as tuple containing the source data and sink data.
    '''
    # Generate filenames based on input parameters
    #outputs_by_channel = []
    output_set = {}
    #if len(sbx.channels) > 1 and split_chan:
    for channel in sbx.channels:
        if split_chan:
            output_set[channel] = 'moco_aligned_{}_{}'.format(sbx.filename, channel)
        else:
            output_set[channel] = 'moco_aligned_{}'.format(sbx.filename)

    if sbx.num_planes >1 and split_planes:
        for channel,output in output_set.items():
            plane_set = {}
            for i in range(sbx.num_planes):
                plane_set['plane_{}'.format(i)] = '{}_plane_{}.sbx'.format(output, i)
            output_set.update({channel: plane_set})
    else:
        for channel,output in output_set.items():
            output_set.update(
                    {channel: {'all': '{}.sbx'.format(output)}}
                    )

    # Generate metadata files (.mat)
    meta = lmat.loadmat(sbx.filename + '.mat')
    if not meta['info']['scanmode']:
        meta['info']['sz'][1] = meta['info']['sz'][1] - 100
    for channel, plane_data in output_set.items():
        for plane, filename in plane_data.items():
            basename = os.path.splitext(filename)[0]
            selected_channel = [ch for ch in channel_options if ch in basename]
            if len(selected_channel):
                channel = selected_channel[0]
                meta['info']['channels'] = channel_lookup[channel]
            if 'plane' in basename:
                meta['info']['resfreq'] = meta['info']['resfreq'] // sbx.num_planes
                meta['info']['otparam'] = []
            spio.savemat(basename + '.mat', {'info':meta['info']})

    rows,cols = sbx.info['sz']
    margin = 0
    if not sbx.info['scanmode']:
        cols = cols - 100
        margin = 100

    source_size = np.prod(((sbx.info['length']+1) * len(sbx.channels), rows, cols))

    # Generate memory-mapped files
    print('Allocating space for aligned data...')
    #orig_mmap_size = os.path.getsize(sbx.filename + '.sbx') // 2 // len(output_set)
    mmap_size = source_size // len(output_set)

    # Ugly method for calculating output file sizes, but it works
    filenames = []
    for channel, plane_data in output_set.items():
        for plane, filename in plane_data.items():
            filenames.append(filename)
    filenames = list(set(filenames))
    for filename in filenames:
        plane = re.findall('plane_[0-9]+', filename)
        ch = [ch for ch in channel_options if ch in filename]
        if len(ch):
            ch = ch[0]
            if len(plane):
                plane = plane[0]
                mmap_size = np.prod(sbx.data()[ch][plane][:,:,margin:].shape)
            else:
                mmap_size = np.prod((cols, rows, sbx.info['length']))
        elif len(plane):
            plane = plane[0]
            mmap_size = np.prod(sbx.data()[sbx.channels[0]][plane][:,:,margin:].shape)*2
        else:
            mmap_size = np.prod((cols, rows, sbx.info['length']*2))
        np.memmap(filename, dtype='uint16', mode='w+', shape=mmap_size)
    return output_set

def generate_templates(sbx, start=20, stop=40):
    '''
    Generates a template for each plane of each channel. Maintains same dictionary
    layout as sbx.data().

    Returns templates.
    '''
    templates = {channel: {} for channel in sbx.channels}
    for channel,planes in sbx.data().items():
        for plane,value in planes.items():
            if not sbx.info['scanmode']:
                templates[channel].update(
                        {plane: value[start:stop,:,100:].mean(0)}
                        )
            else:
                templates[channel].update(
                        {plane: value[start:stop].mean(0)}
                        )
    return templates

def generate_indices(sbx, task_size=10):
    '''
    Generates indices which will be used to distrbute chunks of data across
    multiprocessing pool.

    Returns chunked indices.
    '''
    #depth, rows, cols = sbx.shape
    #framesize = 2 * rows * cols
    all_indices = np.arange(sbx.shape[0])
    if isinstance(task_size, type(None)):
        max_tasks_per_process = all_indices.shape[0]
    else:
        max_tasks_per_process = all_indices.shape[0] / task_size
    return np.array_split(all_indices, max_tasks_per_process)

def generate_translations(sbx):
    '''
    Generates a file to hold the translations.
    '''
    length = sbx.info['length']
    translations_file = tempfile.NamedTemporaryFile(delete=True)
    translations_set = np.memmap(translations_file,
                                 dtype='|S21',
                                 shape=(length, 3),
                                 mode='w+')
    translations_set = {'plane_{}'.format(i): translations_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    for plane in translations_set.values():
        plane[:,0] = 'empty'
    return translations_file, translations_set

def run_parallel(params, num_cpu):
    status = Statusbar(len(params), 50)
    pool = multiprocessing.Pool(num_cpu) # spawning new processes after each task improves performance
    status.initialize()
    for i,_ in enumerate(pool.imap_unordered(kwargs_wrapper, params), 1):
        status.update(i)

def run_serial(params_set):
    status = Statusbar(len(params_set), 50)
    status.initialize()
    for i,params in enumerate(params_set, 1):
        kwargs_wrapper(params)
        status.update(i)

def kwargs_wrapper(kwargs):
    function, kwargs = kwargs
    function(**kwargs)

def generate_visual(filenames, fmt='eps'):
    import matplotlib.pyplot as plt # import here to avoid interference with multiprocessing
    '''
    Generates:
        1. A plot of translation vs time for both x and y for each plane.
        2. A set of X-T and Y-T slices for each plane.
    '''
    common_basename = '_'.join(filenames[0].split('.')[0].split('_'))
    translations = np.load('{}_translations.npy'.format(common_basename)).tolist()

    # Map data for X-T + Y-T slices
    for filename in filenames:
        sbx = sbxmap(filename)
        depth,rows,cols = sbx.shape
        for channel,channel_data in sbx.data().items():
            for plane,data in channel_data.items():
                XT = np.mean(~sbx.data()[channel][plane][:,:,(cols//2)-20:(cols//2)+20],2).T

                # Get max and min pixel values (excluding "false black translation pixels") for proper scaling
                xclim_max = np.max(XT[XT<65535])
                xclim_min = np.min(XT[XT>0])
                xtfig = plt.figure()
                plt.imshow(XT, aspect='auto')
                plt.clim(xclim_min, xclim_max)
                plt.title('X-T Slices')

                # Save figure
                xtfig.savefig('{}_{}_{}_XT.png'.format(common_basename, channel, plane))

                # Repeat for Y-T
                YT = np.mean(~sbx.data()[channel][plane][:,(rows//2)-20:(rows//2)+20,:],1).T
                yclim_max = np.max(YT[YT<65535])
                yclim_min = np.min(YT[YT>0])
                ytfig = plt.figure()
                plt.imshow(YT, aspect='auto')
                plt.clim(yclim_min, yclim_max)
                plt.title('Y-T Slices')
                ytfig.savefig('{}_{}_{}_YT.png'.format(common_basename, channel, plane))

    for plane,translations_set in translations.items():

        # Extract translations
        x = np.int64(translations_set[:,1])
        y = np.int64(translations_set[:,2])

        # Plot and save x translations
        xfig = plt.figure()
        plt.title('X Translations')
        plt.plot(x)
        xfig.savefig('{}_{}_x.{}'.format(common_basename, plane, fmt))

        # Plot and save y translations
        yfig = plt.figure()
        plt.title('Y Translations')
        plt.plot(y)
        yfig.savefig('{}_{}_y.{}'.format(common_basename, plane, fmt))

def main():
    setproctitle('moco')
    oldmask = os.umask(007)
    sbx = sbxmap(sys.argv[1])
    print('Aligning {}.sbx'.format(sbx.filename))

    # Default arguments
    #num_cpu = multiprocessing.cpu_count() # logical
    num_cpu = multiprocessing.cpu_count()/2 # physical
    align_channel = 'red'
    visualize = False
    w = 15
    split_chan = False
    split_planes = False

    # Parse user arguments
    if '-serial' in sys.argv:
        parallel = False
    else:
        parallel = True
    if '-num-cpu' in sys.argv:
        arg_idx = sys.argv.index('-num-cpu')
        num_cpu_arg = sys.argv[arg_idx + 1]
        try:
            num_cpu = int(num_cpu_arg)
            print('Number of cpus set to {}.'.format(num_cpu))
        except:
            raise ValueError('Number of cpus argument must be an integer.')
    if len(sbx.channels)  > 1:
        align_channel_args = [arg for arg in sys.argv if arg in ['-to-green', '-to-red']]
        if len(align_channel_args):
            align_channel = align_channel_args[0].split('-')[-1]
        print('Using {} channel for alignment.'.format(align_channel))
    else:
        align_channel = sbx.channels[0]
    if '-vis' in sys.argv:
        visualize = True
        print('Set to visualize alignment.')
    if '-max' in sys.argv:
        max_idx = sys.argv.index('-max')
        max_arg = sys.argv[max_idx + 1]
        try:
            w = int(max_arg)
            print('Max displacement set to {}.'.format(w))
        except:
            raise ValueError('Max displacement argument must be an integer.')
    if '-split-chan' in sys.argv:
        split_chan = True
    if '-split-plane' in sys.argv:
        split_planes = True

    # Prepare output data
    #source, sink, filenames = generate_output(sbx, split_chan=split_chan, split_planes=split_planes)
    output_set = generate_output(sbx, split_chan=split_chan, split_planes=split_planes)
    templates = generate_templates(sbx)
    translations_file, globe.translations = generate_translations(sbx)
    #t_info = dict(filename=t_handle, dtype=t_handle.dtype, shape=t_handle.shape)
    index_set = generate_indices(sbx)

    # Package arguments to distribute across multiprocessing pool
    params_set = []
    for plane, filename in output_set[align_channel].items():
        for indices in index_set:
            params_set.append(
                               [moco_v2.align,
                                 {
                                  'source_name': sbx.filename + '.sbx',
                                  'sink_name': filename,
                                  'templates': templates,
                                  'cur_plane': plane,
                                  'channel': align_channel,
                                  'indices': indices,
                                  'w': w
                                  }
                                ]
                              )

    # Align!
    print('Using moco alignment.')
    start = time.time()

    if not parallel: # run serially
        print('Aligning serially.')
        print('Aligning...')
        run_serial(params_set)
    else: # run in parallel
        print('Alignment using {} processes.'.format(num_cpu))
        print('Aligning...')
        run_parallel(params_set, num_cpu)

    time_passed = time.time() - start
    print('\nFinished alignent in {:.3f} seconds. Alignment speed: {:.3f} frames/sec.'.format(time_passed, (sbx.shape[0]/time_passed)))

    # Save translations to disk
    translations_filename = 'moco_aligned_{}_translations'.format(sbx.filename)
    np.save(translations_filename, globe.translations)
    translations_file.close()

    # If data is multichannel, apply translations to second channel
    if len(sbx.channels) > 1:
        if align_channel == 'red':
            apply_channel = 'green'
        elif align_channel == 'green':
            apply_channel = 'red'

        apply_params_set = []
        for plane, filename in output_set[apply_channel].items():
            for indices in index_set:
                apply_params_set.append(
                                   [moco_v2.apply_translations,
                                     {
                                      'source_name': sbx.filename + '.sbx',
                                      'sink_name': filename,
                                      'cur_plane': plane,
                                      'channel': apply_channel,
                                      'indices': indices,
                                      }
                                    ]
                                  )

        print('Applying translations to {} channel...'.format(apply_channel))
        if not parallel: # run serially
            run_serial(apply_params_set)
        else: # run in parallel
            run_parallel(apply_params_set, num_cpu)

    # Generate visualization of alignment
    if visualize:
        print('\nGenerating visualization of alignment.')
        filenames = []
        for channel, plane_data in output_set.items():
            for plane, filename in plane_data.items():
                filenames.append(filename)
        generate_visual(filenames)
        print('Done.')

if __name__ == '__main__':
    main()
