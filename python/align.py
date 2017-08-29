import numpy as np
import scipy.io as spio
import multiprocessing
import time
import os
import sys
import tempfile

import moco
import loadmat as lmat
from sbxmap import sbxmap
from statusbar import statusbar

def generate_indices(sbx):
    all_indices = np.arange(sbx.shape[0])
    num_cpu = multiprocessing.cpu_count() / 2
    return np.array_split(all_indices, num_cpu)

def generate_dimensions(sbx):
    if sbx.info['scanmode']: # unidirectional
        dimensions = (sbx.info['length'], sbx.info['sz'][0], sbx.info['sz'][1])
        plane_dimensions = sbx.shape
    else: # bidirectional
        dimensions[2] = dimensions[2] - 100
        plane_dimensions[2] = plane_dimensions[2] - 100
    return dimensions, plane_dimensions

def generate_templates(sbx, source_file=None, template_indices=None):
    if source_file == None:
        input_data_set = sbx.data['green']
    else:
        source_file = os.path.splitext(source_file)[0]
        input_data_set = sbx(source_file)
    if template_indices == None:
        templates = [plane[20:40].mean(0) for plane in input_data_set.values()]
    else:
        template_indices = slice(template_indices)
        templates = [plane[template_indices].mean(0) for plane in input_data_set.values()]
    templates = map(np.uint16, templates) # convert tempaltes to uint16
    return templates

def generate_translations(sbx):
    dimensions = (sbx.info['length'], sbx.info['sz'][0], sbx.info['sz'][1])
    translations_file = tempfile.NamedTemporaryFile(delete=True)
    translations_set = np.memmap(translations_file,
                                 dtype='int64',
                                 shape=(dimensions[0], 2),
                                 mode='w+')

    translations_set = {'plane_{}'.format(i): translations_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
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

def run_alignment(params, func='moco'):
    align_functions = {'moco' : moco.align} # list of possible alignment functions
    align_func = align_functions[func] # select alignment function
    print('Using {} alignment.'.format([k for k,v in align_functions.items() if v is align_func][0]))
    status = statusbar(50)
    params[-1].update({'status':status}) # pass statusbar to last process

    # create pool of processes and start alignment
    pool = [multiprocessing.Process(target=align_func, kwargs=params) for params in params_set]
    for i, process in enumerate(pool):
        print('Starting process {}'.format(i + 1))
        process.start()

    print('Aligning...')
    time_passed = status.run()
    print('\nFinished alignent in {:.3f} seconds. Alignment speed: {:.3f} frames/sec.'.format(time_passed, (sbx.shape[0]/time_passed)))

if __name__ == '__main__':
    filename = os.path.splitext(sys.argv[1])[0]
    sbx = sbxmap(filename)
    indices = generate_indices(sbx)
    dimensions, plane_dimensions = generate_dimensions(sbx)
    translations = generate_translations(sbx)
    templates = generate_templates(sbx)
    print('Allocating space for aligned data...')
    output_data_set = generate_output(sbx, dimensions, plane_dimensions, split=True)
    func = 'moco'
    savemat = False
    # TODO: Include variable w selection for Carey's high mag recordings.

    params_set = []
    for i in indices:
        params_set.append(dict(sbx=sbx,
                           indices=i,
                           translations=translations,
                           templates=templates,
                           savemat=savemat)
                           )

    run_alignment(params_set, func)

    # save metadata and translations
    save_mat(sbx, output_data_set, split=True)
    channel = '_green' if len(sbx.channels) > 1 else ''
    translations_filename = 'moco_aligned_{}{}_translations'.format(sbx.filename, channel)
    np.save(translations_filename, translations)
