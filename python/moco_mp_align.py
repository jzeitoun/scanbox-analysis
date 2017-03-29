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
    transform_file = tempfile.mktemp()
    transforms = np.memmap(transform_file, dtype='int64', mode = 'w+', shape =(info['length'],2))
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
 
    ds_template = cv2.pyrDown(template)   

    # set max displacement to 190 if magnification is 8x
    if info['magnification'] == 8:
        w_val = 190
    else:
        w_val = 15

    print 'Allocating space for aligned data...'
    output_data = np.memmap('Moco_Aligned_' + filename + '.sbx', dtype='uint16', shape=(info['length'], info['sz'][0], info['sz'][1]), mode = 'w+')
    
    num_cores = multiprocessing.cpu_count()/2
    #core_assignments = [[np.arange(core,mapped_data.shape[0],num_cores), mapped_data[core::num_cores]] for core in range(num_cores)]
    core_assignments = [np.arange(core,mapped_data.shape[0],num_cores) for core in range(num_cores)]

    q = Queue()
    
    print 'Max displacement:',w_val
    print 'Creating processes...'
    processes = [Process(target=align_purepy, args=(filename,indices,template,ds_template, info['length'], info['sz'][0], mapped_width, info['sz'][1], transform_file, q, info['scanmode'], w_val)) for indices in core_assignments]
    
    start = time.time()

    for number,process in enumerate(processes):
        process.start()
        print 'Started process ', (number + 1)
	
    print 'Aligning...'
    
    q_list = []
   
    # confirm that all frames were aligned
    while True:
        try:
            q_list.append(q.get(timeout=5))
        except Empty:
            end = time.time()-5
            break

    max_aligned_idx = max(q_list)
    elapsed_time = time.time() - start 

    print 'Finished. Aligned %d frames in %d seconds' % (max_aligned_idx, elapsed_time)
    print 'Alignment speed: %d frames/sec' % (max_aligned_idx/elapsed_time)

    np.save('Moco_Aligned_' + filename + '_trans',transforms)
    spio_info = loadmat(filename + '.mat')
    spio_info['info']['sz'] = info['sz']
    spio.savemat('Moco_Aligned_' + filename + '.mat',{'info':spio_info['info']})

    del transforms
    _ = gc.collect()
    os.remove(transform_file)


