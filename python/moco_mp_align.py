import multiprocessing
from multiprocessing import Process, Queue
from Queue import Empty
import os
import time
import sys
import tempfile
import gc

from align_functions import *
from sbxread import *
       

if __name__ == '__main__':
    
    filename = sys.argv[1]
    if 'sbx' in filename:
        filename = filename[:-4]

    info = sbxread(filename)
    mapped_data = sbxmap(filename + '.sbx') #np.memmap(filename + '.sbx', dtype='uint16', shape=(info['length'], info['sz'][0], info['sz'][1]))
    transform_file = tempfile.NamedTemporaryFile(delete=True)
    transforms = np.memmap(transform_file, dtype='int64', mode = 'r+', shape =(info['length'],2))
    mapped_width = info['sz'][1]

    # if second filename is supplied, use template from that file for alignment
    if len(sys.argv) > 2:
        align_filename = sys.argv[2]
        mapped_align_filename = sbxmap(align_filename + '.sbx')
        template = np.uint16(np.mean(mapped_align_filename[20:40,:], 0))
    else:
        template = np.uint16(np.mean(mapped_data[20:40,:], 0))

    # need to crop left margin if data is bidirectional
    if info['scanmode'] == 0:
        info['sz'][1] = info['sz'][1]-100
        template = template[:,100:]

    # set max displacement to 190 if magnification is 8x
    if ('magnification' in info and info['magnification'] == 8) | info['config']['magnification'] == 8:
        w_val = 80
    else:
        w_val = 15

    print 'Allocating space for aligned data...'
    output_data = np.memmap('Moco_Aligned_' + filename + '.sbx', dtype='uint16', shape=(info['length'], info['sz'][0], info['sz'][1]), mode = 'w+')
    
    num_cores = multiprocessing.cpu_count()/2
    all_idx = np.arange(info['length'])
    core_assignments = np.array_split(all_idx, num_cores)
    #core_assignments = [np.arange(core,mapped_data.shape[0],num_cores) for core in range(num_cores)]

    # this queue will be used to track the progress of alignment
    q = Queue()
    
    print 'Max displacement:',w_val
    print 'Creating processes...'

    processes = [
            Process(
                target=align_purepy,
                args=(
                    filename,
                    indices,
                    template,
                    info['length'],
                    info['sz'][0],
                    mapped_width,
                    info['sz'][1],
                    transforms,
                    num_cores,
                    p_num+1,
                    q,
                    info['scanmode'],
                    w_val
                )
            ) for p_num, indices in enumerate(core_assignments)
        ]

    start = time.time()

    for number,process in enumerate(processes):
        process.start()
        print 'Started process ', (number + 1)

    time.sleep(0.5)

    print 'Aligning...'

    # update status of alignment
    sys.stdout.write('\r')
    sys.stdout.write('[{:50s}] {}%'.format('=' * 0, 0))
    sys.stdout.flush()
    for i in iter(q.get, 'STOP'):
        sys.stdout.write('\r')
        sys.stdout.write('[{:50s}] {}%'.format('=' * i, 2 * i))
        sys.stdout.flush()

    time.sleep(0.5)

    elapsed_time = time.time() - start

    print '\nFinished. Aligned %d frames in %d seconds' % (info['length'], elapsed_time)
    print 'Alignment speed: %d frames/sec' % (info['length']/elapsed_time)

    np.save('Moco_Aligned_' + filename + '_trans',transforms)
    spio_info = loadmat(filename + '.mat')
    spio_info['info']['sz'] = info['sz']
    spio.savemat('Moco_Aligned_' + filename + '.mat',{'info':spio_info['info']})
    transform_file.close()
