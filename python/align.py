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
from statusbar import statusbar

def generate_indices(sbx, max_tasks_per_process=50):
    depth, rows, cols = sbx.shape
    framesize = 2 * rows * cols
    all_indices = np.arange(sbx.shape[0])
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

def generate_templates(sbx, margin, source_file=None, template_indices=None):
    if source_file == None:
        input_data_set = sbx.data['green']
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
        plane[:,1] = 'empty'
    return translations_set

def generate_output(sbx, dimensions, plane_dimensions, split=True):
    channel = '_green' if len(sbx.channels) > 1 else ''
    if split == False or sbx.num_planes == 1:
        filename = 'moco_aligned_{}{}.sbx'.format(sbx.filename, channel)
        mode = 'r+' if os.path.exists(filename) else 'w+'
        output_data_set = np.memmap(filename,
                                    dtype='uint16',
                                    shape=(dimensions),
                                    mode=mode)
        output_data_set = {'plane_{}'.format(i): output_data_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    elif split == True:
        output_data_set = {}
        for plane in range(sbx.num_planes):
            filename = 'moco_aligned_{}{}_plane_{}.sbx'.format(sbx.filename, channel, plane)
            mode = 'r+' if os.path.exists(filename) else 'w+'
            output_data_set.update({'plane_{}'.format(plane):np.memmap(filename,
                                                                       dtype='uint16',
                                                                       shape=(plane_dimensions),
                                                                       mode=mode)
                                                                       })
    return output_data_set

def save_mat(sbx, output_data_set, split=True):
    spio_info = lmat.loadmat(sbx.filename + '.mat')
    for plane, output_data in output_data_set.items():
        spio_info['info']['sz'] = output_data.shape[1:]
        spio_info['info']['channels'] = 2 # TODO: may need to update when including red channel
        if split == True:
            spio_info['info']['resfreq'] = spio_info['info']['resfreq'] / sbx.num_planes
            spio_info['info']['otparam'] = []
        spio.savemat(os.path.splitext(output_data.filename)[0] + '.mat', {'info':spio_info['info']})

def kwargs_call(kwargs):
    align_functions = {'moco' : moco.align}
    selection = kwargs.pop('func')
    align_func = align_functions[selection]
    align_func(**kwargs)

def run_alignment(params, num_cpu=None):
    if 'linux' in sys.platform:
        os.system("taskset -p 0xff %d" % os.getpid()) # ensures that cpu affinity remains high
    if isinstance(num_cpu, type(None)):
        num_cpu = multiprocessing.cpu_count()
    print('Using {} alignment.'.format(params[0]['func']))
    print('Alignment using {} processes.'.format(num_cpu))
    status = statusbar(len(params))
    pool = multiprocessing.Pool(num_cpu, maxtasksperchild=1) # spawning new processes after each task improves performance
    print('Aligning...')
    status.initialize()
    start = time.time()
    for i,_ in enumerate(pool.imap_unordered(kwargs_call, params), 1):
        status.update(i)
    time_passed = time.time() - start
    print('\nFinished alignent in {:.3f} seconds. Alignment speed: {:.3f} frames/sec.'.format(time_passed, (sbx.shape[0]/time_passed)))

if __name__ == '__main__':
    setproctitle('moco')
    filename = os.path.splitext(sys.argv[1])[0]
    if len(sys.argv) > 2:
        num_cpu = int(sys.argv[2])
    sbx = sbxmap(filename)
    indices = generate_indices(sbx)
    margin, dimensions, plane_dimensions = generate_dimensions(sbx)
    translations = generate_translations(sbx)
    templates = generate_templates(sbx, margin)
    print('Allocating space for aligned data...')
    output_data_set = generate_output(sbx, dimensions, plane_dimensions, split=True)
    func = 'moco'
    savemat = False
    # TODO: Include variable w selection for Carey's high mag recordings.

    params_set = []
    for i in indices:
        params_set.append(dict(func=func,
                           sbx=sbx,
                           indices=i,
                           translations=translations,
                           templates=templates,
                           savemat=savemat)
                           )

    run_alignment(params_set, num_cpu)

    # save metadata and translations
    save_mat(sbx, output_data_set, split=True)
    channel = '_green' if len(sbx.channels) > 1 else ''
    translations_filename = 'moco_aligned_{}{}_translations'.format(sbx.filename, channel)
    np.save(translations_filename, translations)
