import numpy as np
import scipy.io as spio
import multiprocessing
import time
import re
import os
import stat
import sys
import tempfile
import shutil
from pathlib import Path
from setproctitle import setproctitle

from difflib import SequenceMatcher


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
    Generates dictionary of memory-mapped files organized by channel and plane.
    '''
    # Generate filenames based on input parameters
    output_set = {}
    fpath = os.path.dirname(sbx.filename)
    filename = os.path.basename(sbx.filename)
    for channel in sbx.channels:

        if split_chan:
            output_set[channel] = os.path.join(fpath, 'moco_aligned_{}_{}'.format(filename, channel))
        else:
            output_set[channel] = os.path.join(fpath, 'moco_aligned_{}'.format(filename))
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
    meta['info']['resfreq'] = meta['info']['resfreq'] // sbx.num_planes
    try:
        mesoscope_fields = meta['info'].get('mesoscope').get('roi_table')
    except:
        mesoscope_fields =  None
    if split_planes and not isinstance(mesoscope_fields, type(None)):
        meta['info'].get('mesoscope').pop('roi_table')
    if not meta['info']['scanmode']:
        meta['info']['sz'][1] = meta['info']['sz'][1] - 100
    for channel, plane_data in output_set.items():
        for plane, fn in plane_data.items():
            basename = os.path.splitext(fn)[0]
            selected_channel = [ch for ch in channel_options if ch in basename]
            if len(selected_channel):
                channel = selected_channel[0]
                meta['info']['channels'] = channel_lookup[channel]
            if 'plane' in basename:
                meta['info']['otparam'] = []

            spio.savemat(basename + '.mat', {'info':meta['info']})
            os.chmod(basename + '.mat', stat.S_IRWXU | stat.S_IRGRP | stat.S_IROTH)

    # Generate memory-mapped files
    print('Allocating space for aligned data...')

    # Ugly method for calculating output file sizes, but it works
    rows,cols = sbx.info['sz']
    margin = 0
    if not sbx.info['scanmode']:
        cols = cols - 100
        margin = 100
    filenames = []
    for channel, plane_data in output_set.items():
        for plane, fn in plane_data.items():
            filenames.append(fn)
    filenames = list(set(filenames))
    for fn in filenames:
        plane = re.findall('plane_[0-9]+', fn)
        ch = [ch for ch in channel_options if ch in fn]
        if len(ch):
            ch = ch[0]
            if len(plane):
                plane = plane[0]
                mmap_size = np.prod(sbx.data()[ch][plane][:,:,margin:].shape)
            else:
                mmap_size = np.prod((cols, rows, sbx.info['length']))
        elif len(plane):
            factor = 2 if len(sbx.channels) > 1 else 1
            plane = plane[0]
            mmap_size = np.prod(sbx.data()[sbx.channels[0]][plane][:,:,margin:].shape) * factor
        else:
            mmap_size = np.prod((cols, rows, sbx.info['length']*sbx.info['nChan']))
        np.memmap(fn, dtype='uint16', mode='w+', shape=mmap_size)
        os.chmod(fn, stat.S_IRWXU | stat.S_IRGRP | stat.S_IROTH)
    return output_set

def generate_templates(sbx, method=np.mean, start=20, stop=40):
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
                        {plane: method(value[start:stop,:,100:], 0)}
                        )
                if method == np.sum:
                    template = templates[channel][plane]
                    uint16_template = np.uint16((template*65535/float(template.max())))
                    templates[channel][plane] = uint16_template
            else:
                templates[channel].update(
                        {plane: method(value[start:stop], 0)}
                        )
                if method == np.sum:
                    template = templates[channel][plane]
                    uint16_template = np.uint16((template*65535/float(template.max())))
                    templates[channel][plane] = uint16_template

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
    status = Statusbar(len(params), barsize=50)
    pool = multiprocessing.Pool(num_cpu)
    status.initialize()
    for i,_ in enumerate(pool.imap_unordered(kwargs_wrapper, params), 1):
        status.update(i)
    pool.close()

def run_serial(params_set):
    status = Statusbar(len(params_set), barsize=50)
    status.initialize()
    for i,params in enumerate(params_set, 1):
        kwargs_wrapper(params)
        status.update(i)

def kwargs_wrapper(kwargs):
    function, kwargs = kwargs
    function(**kwargs)

def generate_visual(filenames, fmt='eps'):
    import matplotlib
    matplotlib.use('agg')
    import matplotlib.pyplot as plt # import here to avoid interference with multiprocessing
    '''
    Generates:
        1. A plot of translation vs time for both x and y for each plane.
        2. A set of X-T and Y-T slices for each plane.
    '''

    if len(filenames) > 1:
        match = SequenceMatcher(None, filenames[0], filenames[1]).find_longest_match(0, len(filenames[0]), 0, len(filenames[1]))
        common_basename = filenames[0][match.a : match.b + match.size]
        common_basename = common_basename.replace('_plane_', '')
    else:
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
        translations_set_x = translations_set[:,1]
        translations_set_x = translations_set_x[translations_set_x != b'']
        x = np.int64(translations_set_x)
        translations_set_y = translations_set[:,2]
        translations_set_y = translations_set_y[translations_set_y != b'']
        y = np.int64(translations_set_y)

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

def run():
    setproctitle('moco')
    oldmask = os.umask(0o007)
    sbx = sbxmap(sys.argv[0])
    print('Aligning {}.sbx'.format(sbx.filename))

    # Default arguments
    num_cpu = multiprocessing.cpu_count()//2 # physical
    align_channel = 'red'
    visualize = False
    w = 15
    t_start = 20
    t_stop = 40
    t_method = np.mean
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
    if '-t-range' in sys.argv:
        t_range_idx = sys.argv.index('-t-range')
        t_start = sys.argv[t_range_idx + 1]
        t_stop = sys.argv[t_range_idx + 2]
        try:
            t_start = int(t_start)
            t_stop = int(t_stop)
            print('Templates will use range {} - {}.'.format(t_start, t_stop))
        except:
            raise ValueError('Template indices must be integers.')
    if '-t-method' in sys.argv:
        method_lookup = {
                    'mean': np.mean,
                    'max': np.max,
                    'sum': np.sum
                    }
        try:
            method_idx = sys.argv.index('-t-method')
            t_method = method_lookup[sys.argv[method_idx + 1]]
            print('Template generation will use {}.'.format(sys.argv[method_idx + 1]))
        except:
            raise ValueError('Template method must be "mean", "max" or "sum".')


    # Prepare output data
    output_set = generate_output(sbx, split_chan=split_chan, split_planes=split_planes)
    templates = generate_templates(sbx, method=t_method, start=t_start, stop=t_stop)
    translations_file, globe.translations = generate_translations(sbx)
    index_set = generate_indices(sbx)

    # Package arguments to distribute across multiprocessing pool
    params_set = []
    for plane, fn in output_set[align_channel].items():
        for indices in index_set:
            params_set.append(
                               [moco_v2.align,
                                 {
                                  'source_name': sbx.filename + '.sbx',
                                  'sink_name': fn,
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
    fpath = os.path.dirname(sbx.filename)
    filename = os.path.basename(sbx.filename)

    translations_filename = os.path.join(fpath, 'moco_aligned_{}_translations'.format(filename))
    np.save(translations_filename, globe.translations)
    translations_file.close()

    # If data is multichannel, apply translations to second channel
    if len(sbx.channels) > 1:
        if align_channel == 'red':
            apply_channel = 'green'
        elif align_channel == 'green':
            apply_channel = 'red'

        apply_params_set = []
        for plane, fn in output_set[apply_channel].items():
            for indices in index_set:
                apply_params_set.append(
                                   [moco_v2.apply_translations,
                                     {
                                      'source_name': sbx.filename + '.sbx',
                                      'sink_name': fn,
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
            for plane, fn in plane_data.items():
                filenames.append(fn)
        generate_visual(filenames)
        print('Done.')

def copyfileobj(fsrcname, fdstname, callback, length=16*1024):
    with open(fsrcname) as fsrc, open(fdstname, 'w+') as fdst:
        fsize = os.path.getsize(fsrcname)
        copied = 0
        while True:
            buf = fsrc.buffer.read(length)
            if not buf:
                break
            fdst.buffer.write(buf)
            copied += len(buf)
            percent = copied/fsize*100
            callback(percent)

def displayProgressPercent(val):
    sys.stdout.write('\r')
    sys.stdout.write('Copying File: {:.2f}%'.format(val))
    sys.stdout.flush()

def main():
    if '-a' in sys.argv: # aligns all files in current directory
        raw     = [fn for fn in os.listdir('.') if fn.endswith('.sbx') and 'moco_aligned_' not in fn]
        aligned = [fn for fn in os.listdir('.') if fn.endswith('.sbx') and 'moco_aligned_' in fn]
    elif '-r' in sys.argv: # aligns all files in current directory recursivly
        raw     = [os.path.join(root, fn) for root, dirs, files in os.walk(os.getcwd()) for fn in files if fn.endswith('.sbx') and 'moco_aligned_' not in fn]
        aligned = [os.path.join(root, fn) for root, dirs, files in os.walk(os.getcwd()) for fn in files if fn.endswith('.sbx') and 'moco_aligned_' in fn]
    else:
        raw 	= [sys.argv[1]]
        aligned = []
    if '-ignore' in sys.argv: # do not align files with an associated moco aligned file
        initial = len(raw)
        aligned = [a.replace('moco_aligned_', '') for a in aligned]
        raw = list(set(raw) - set(aligned))
        print ('{} of {} sbx files to be converted'.format(len(raw),initial))
    if not raw:
        raise ValueError('sbx file not defined or no files found in current directory.')

    print('Batch processing: {} sbx files'.format(len(raw)))
    for i,f in enumerate(raw):
        fname = Path(f)
        print('Aligning file {} of {}'.format(i+1, len(raw)))
        sys.argv[0] = f # messy way because run() only knows which file by position in sys.argv
        if '-debug' in sys.argv:
            from ipdb import launch_ipdb_on_exception
            sys.argv.append('-serial')
            with launch_ipdb_on_exception():
                tmpdir = tempfile.TemporaryDirectory(dir='/mnt/swap')
                tempf = os.path.join(tmpdir.name, fname)
                shutil.copy(fname.with_suffix('.mat'), tmpdir.name)
                copyfileobj(f, tempf, displayProgressPercent)
                cwd = os.getcwd()
                os.chdir(tmpdir.name)

                run()

                os.chdir(cwd)
                alignedf = Path('moco_aligned_' + f)
                outf = os.path.join(tmpdir.name, alignedf)
                shutil.copy(os.path.join(tmpdir.name, alignedf.with_suffix('.mat')), cwd)
                copyfileobj(outf, alignedf, displayProgressPercent)
                tmpdir.cleanup()
        else:
            tmpdir = tempfile.TemporaryDirectory(dir='/mnt/swap')
            tempf = os.path.join(tmpdir.name, fname)
            shutil.copy(fname.with_suffix('.mat'), tmpdir.name)
            copyfileobj(f, tempf, displayProgressPercent)
            cwd = os.getcwd()
            os.chdir(tmpdir.name)

            run()

            os.chdir(cwd)
            alignedf = Path('moco_aligned_' + f)
            outf = os.path.join(tmpdir.name, alignedf)
            shutil.copy(os.path.join(tmpdir.name, alignedf.with_suffix('.mat')), cwd)
            copyfileobj(outf, alignedf, displayProgressPercent)
            tmpdir.cleanup()

if __name__ == '__main__':
    main()
