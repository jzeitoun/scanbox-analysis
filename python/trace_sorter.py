




def sort_vector(io_file,vector):
    #os.mkdir(io_file + '-analysis')                                              
    #dir_path = os.path.abspath(io_file + '-analysis')                            
    path = os.getcwd()                                                           
    io = ScanboxIO(os.path.join(path,io_file + '.io'))                           
    conditions = [dict(t.attributes) for t in io.condition.trials]
    #workspace = [w for w in io.condition.workspaces if w.name == _workspace][0]  
    #rois = [roi for roi in workspace.rois]                                       
    framerate = io.condition.framerate                                           
    #trailing_frames = np.int64(trailing_seconds * framerate)                     
    #num_on_frames = rois[0].dtorientationsmeans.first.on_frames                  
    num_on_frames = int(framerate * io.condition.on_duration)   
    num_off_frames = int(framerate * io.condition.off_duration)
    sfreqs = io.condition.sfrequencies
    oris = io.condition.orientations

    on_times = np.array([d['on_time'] for d in conditions])                                
    off_times = np.array([d['off_time'] for d in conditions])                              
                                                                                          
    on_frames = np.int64(on_time * framerate)                                              
    off_frames = np.int64(off_time * framerate)                                            
                                                                                          
    on_idx = zip(on_frames,on_frames + num_on_frames)                                       
    off_idx = zip(off_frames,off_frames + num_off_frames) #np.append(on_frames[1:],on_frames[-1] + min(np.diff(on_frames))))

    for c,d1,d2 in zip(conditions,on_idx,off_idx):                                                         
        c.update(                                                                                          
            {'on_start_frame':d1[0],'on_end_frame':d1[1],                                                  
            'off_start_frame':d2[0],'off_end_frame':d2[1]}                                                 
            )                                                                                              
                                                                                                           
    # remove trials if not enough frames                                                                   
    #if len(dtoverallmeans) < conditions[-1]['on_end_frame']:                                               
    #    max_idx = min([conditions.index(c) for c in conditions if c['on_end_frame'] > len(dtoverallmeans)])
    #    conditions = conditions[:max_idx]                                                                  
                                                                                                           
    # sort frames                                                                                          
    for c in conditions:                                                                                   
        c.update(                                                                                          
            {'on_frame_values':                                                                            
                vector[c['on_start_frame']:c['on_end_frame']],                                     
            'off_frame_values':                                                                            
                vector[c['off_start_frame']:c['off_end_frame']]}                                   
            )                                                                                              

    return conditions

def heatmap_on(filename,conditions):
    ori_dict = {ori:i for i,ori in enumerate(oris)}
    sfreq_dict = {sf:i for i,sf in enumerate(sfreqs)}

    heatmap = np.zeros([len(ori_dict.keys()),len(sfreq_dict.keys())])

    sorted_list = []              
    for sf in sfreq_dict:                          
        for ori in ori_dict:                                                                       
            sorted_list.append([ori,sf,np.mean([c['on_frame_values'] for c in conditions if c['ori'] == ori and c['sf'] == sf])])

    for ori,sf,val in sorted_list:
        heatmap[ori_dict[ori],sfreq_dict[sf]] = val
 
    heatmap = heatmap[::-1,::-1] 

    np.save(filename,{'sfreq_dict':sfreq_dict, 'ori_dict':ori_dict, 'heatmap':heatmap})
