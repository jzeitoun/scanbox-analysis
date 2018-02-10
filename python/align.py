import numpy as np
import scipy.io as spio
import multiprocessing
import time
import os
import sys
import tempfile

from setproctitle import setproctitle
import moco
import loadmat as lmat
from sbxmap import sbxmap
from statusbar import Statusbar

def generate_indices(sbx, task_size=10):
    depth, rows, cols = sbx.shape
    framesize = 2 * rows * cols
    all_indices = np.arange(sbx.shape[0])
    if isinstance(task_size, type(None)):
        max_tasks_per_process = all_indices.shape[0]
    else:
        max_tasks_per_process = all_indices.shape[0] / task_size
    return np.array_split(all_indices, max_tasks_per_process)

def generate_dimensions(sbx):
    dimensions = [sbx.info['length'], sbx.info['sz'][0], sbx.info['sz'][1]]
    plane_dimensions = list(sbx.shape)
    margin = 0
    if not sbx.info['scanmode']: # bidirectional
        dimensions[2] = dimensions[2] - 100
        plane_dimensions[2] = plane_dimensions[2] - 100
        margin = 100
    return margin, tuple(dimensions), tuple(plane_dimensions)

def generate_templates(sbx, margin, channel='green', source_file=None, template_indices=None):
    if source_file == None:
        if len(sbx.channels) > 1:
            input_data_set = sbx.data()[channel]
        else:
            input_data_set = sbx.data()[sbx.channels[0]]
    else:
        source_file = os.path.splitext(source_file)[0]
        input_data_set = sbx(source_file)
    if template_indices == None:
        templates = [plane[20:40,:,margin:].mean(0) for plane in input_data_set.values()]
    else:
        template_indices = slice(template_indices)
        templates = [plane[template_indices,:,margin:].mean(0) for plane in input_data_set.values()]
    templates = map(np.uint16, templates) # convert tempaltes to uint16
    return templates

def generate_translations(sbx):
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

def generate_output(sbx, dimensions, plane_dimensions, channel='green', split=True):
    if len(sbx.channels) > 1:
        _channel = '_' + channel
    else:
        _channel = ''
    if split == False or sbx.num_planes == 1:
        filename = 'moco_aligned_{}{}.sbx'.format(sbx.filename, _channel)
        mode = 'r+' if os.path.exists(filename) else 'w+'
        output_data_set = np.memmap(filename,
                                    dtype='uint16',
                                    shape=(dimensions),
                                    mode=mode)
        output_data_set = {'plane_{}'.format(i): output_data_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    elif split == True:
        output_data_set = {}
        for plane in range(sbx.num_planes):
            filename = 'moco_aligned_{}{}_plane_{}.sbx'.format(sbx.filename, _channel, plane)
            mode = 'r+' if os.path.exists(filename) else 'w+'
            output_data_set.update({'plane_{}'.format(plane):np.memmap(filename,
                                                                       dtype='uint16',
                                                                       shape=(plane_dimensions),
                                                                       mode=mode)
                                                                       })
    return output_data_set

def save_mat(sbx, output_data_set, channel='green', split=True):
    channels = {'green': 2, 'red': 3}
    spio_info = lmat.loadmat(sbx.filename + '.mat')
    spio_info['info']['channels'] = channels[channel]
    if split == True:
        spio_info['info']['resfreq'] = spio_info['info']['resfreq'] / sbx.num_planes
        spio_info['info']['otparam'] = []
    for plane, output_data in output_data_set.items():
        spio_info['info']['sz'] = output_data.shape[1:]
        spio.savemat(os.path.splitext(output_data.filename)[0] + '.mat', {'info':spio_info['info']})

def kwargs_wrapper(kwargs):
    function, kwargs = kwargs
    function(**kwargs)

def run_alignment(params, num_cpu=None):
    if isinstance(num_cpu, type(None)):
        num_cpu = multiprocessing.cpu_count()
    print('Using moco alignment.') # modify for future alternative alignment scripts.
    print('Alignment using {} processes.'.format(num_cpu))
    status = Statusbar(len(params), 50)
    pool = multiprocessing.Pool(num_cpu) # spawning new processes after each task improves performance
    print('Aligning...')
    status.initialize()
    start = time.time()
    for i,_ in enumerate(pool.imap_unordered(kwargs_wrapper, params), 1):
        status.update(i)
    time_passed = time.time() - start
    print('\nFinished alignent in {:.3f} seconds. Alignment speed: {:.3f} frames/sec.'.format(time_passed, (sbx.shape[0]/time_passed)))

def generate_visual(filename, fmt='eps'):
    import matplotlib.pyplot as plt # import here to avoid interference with multiprocessing
    '''
    Generates:
        1. A plot of translation vs time for both x and y for each plane.
        2. A set of X-T and Y-T slices for each plane.
    '''
    filename = os.path.split(filename)[1]
    basename = os.path.splitext(filename)[0]
    common_basename = '_'.join(basename.split('_')[:5])
    translations = np.load('{}_translations.npy'.format(common_basename)).tolist()

    contents = os.listdir(os.getcwd())
    matched_filenames = list(set([os.path.splitext(f)[0] for f in contents if (common_basename in f) and ('translations' not in f)]))
    # map data for X-T + Y-T slices
    for basename in matched_filenames:
        sbx = sbxmap(basename + '.sbx')
        depth,rows,cols = sbx.shape
        for channel,channel_data in sbx.data().items():
            for plane,data in channel_data.items():
                XT = np.mean(~sbx.data()[channel][plane][:,:,(cols//2)-20:(cols//2)+20],2).T
                # get max and min pixel values (excluding "false black translation pixels") for proper scaling
                xclim_max = np.max(XT[XT<65535])
                xclim_min = np.min(XT[XT>0])
                xtfig = plt.figure()
                plt.imshow(XT, aspect='auto')
                plt.clim(xclim_min, xclim_max)
                plt.title('X-T Slices')
                # save figure
                xtfig.savefig('{}_XT.png'.format(basename))
                # repeat for Y-T
                YT = np.mean(~sbx.data()[channel][plane][:,(rows//2)-20:(rows//2)+20,:],1).T
                yclim_max = np.max(YT[YT<65535])
                yclim_min = np.min(YT[YT>0])
                ytfig = plt.figure()
                plt.imshow(YT, aspect='auto')
                plt.clim(yclim_min, yclim_max)
                plt.title('Y-T Slices')
                ytfig.savefig('{}_YT.png'.format(basename))

    for plane,translations_set in translations.items():
        # extract translations
        x = np.int64(translations_set[:,1])
        y = np.int64(translations_set[:,2])
        # plot and save x translations
        xfig = plt.figure()
        plt.title('X Translations')
        plt.plot(x)
        xfig.savefig('{}_{}_x.{}'.format(common_basename, plane, fmt))
        # plot and save y translations
        yfig = plt.figure()
        plt.title('Y Translations')
        plt.plot(y)
        yfig.savefig('{}_{}_y.{}'.format(common_basename, plane, fmt))


if __name__ == '__main__':
    setproctitle('moco')
    oldmask = os.umask(007)
    filename = os.path.splitext(sys.argv[1])[0]
    num_cpu = None
    sbx = sbxmap(filename)
    channel = sbx.channels[0] # default channel to align is the first channel in the file
    align_to_red = False
    visualize = False
    w = 15
    if 'green' in sys.argv:
        channel = 'green'
    if 'red' in sys.argv:
        channel = 'red'
    if '-to-red' in sys.argv:
        if len(sbx.channels) > 1:
            channel = 'red'
            align_to_red = True
        else:
            print('File only contains one channel. Aligning {}.'.format(channel))
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
    indices = generate_indices(sbx)
    margin, dimensions, plane_dimensions = generate_dimensions(sbx)
    translations_file, translations_set = generate_translations(sbx)
    templates = generate_templates(sbx, margin)
    print('Allocating space for aligned data...')
    output_data_set = generate_output(sbx, dimensions, plane_dimensions, channel, split=True)
    savemat = False

    params_set = []
    for i in indices:
        params_set.append(
                           [moco.align,
                             {
                              'sbx': sbx,
                              'channel': channel,
                              'indices': i,
                              'translations': translations_file.name,
                              'templates': templates,
                              'savemat': savemat
                              }
                            ]
                          )

    run_alignment(params_set, num_cpu)

    # save metadata and translations
    save_mat(sbx, output_data_set, split=True)
    _channel = '_' + channel

    translations_filename = 'moco_aligned_{}_translations'.format(sbx.filename)
    np.save(translations_filename, translations_set)
    translations_file.close()

    # align green channel to red
    if align_to_red == True:
        channel = 'green'
        green_output_data_set = generate_output(sbx, dimensions, plane_dimensions, channel=channel, split=True)
        apply_params = []
        for i in indices:
            apply_params.append(
                               [moco.apply_translations,
                                 {
                                   'sbx': sbx,
                                   'translations_filename': translations_filename,
                                   'channel': channel,
                                   'dimensions': dimensions,
                                   'plane_dimensions': plane_dimensions,
                                   'indices': i
                                   }
                                 ]
                               )
        pool = multiprocessing.Pool(multiprocessing.cpu_count())
        status = Statusbar(len(apply_params))
        print('Applying translations to {} channel...'.format(channel))
        status.initialize()
        for i,_ in enumerate(pool.imap_unordered(kwargs_wrapper, apply_params), 1):
            status.update(i)
        save_mat(sbx, green_output_data_set, split=True)

    # added to generate visualization of alignment
    if visualize:
        print('\nGenerating visualization of alignment.')
        generate_visual(output_data_set.values()[0].filename)
        print('Done.')

