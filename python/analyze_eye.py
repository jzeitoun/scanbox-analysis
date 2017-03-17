import numpy as np
import h5py
import cv2
import tifffile as tif

def analyze_eye(fname,write=0):
    '''
    Calculates pupil area and saves as .npy file.
    If write = 1, will also write out data with tracked pupil.
    '''
    # read in eye data
    data = h5py.File(fname + '.mat')
    eye_data = np.squeeze(np.array(data['data'])).transpose(0,2,1)
    eye_data_center = np.array(eye_data.shape[1:3])/2
    area_trace = np.zeros(eye_data.shape[0])
    centroid_trace = np.int32(np.zeros([eye_data.shape[0],2])) # centroid is in xy coordinates
    r_effective = 1.25
    pixels_per_mm = 100

    if write:
        rgb_eye_data = np.uint8(np.zeros([eye_data.shape[0],eye_data.shape[1],eye_data.shape[2],3]))
	for i in range(eye_data.shape[0]):
            # find center of eye
           #ret,eye_thresh = cv2.threshold(eye_data[i].copy(),18,255,cv2.THRESH_BINARY)
           #eye_contours,hierarchy = cv2.findContours(eye_thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
           ##eye_hulls = [cv2.convexHull(eye_contour) for eye_contour in eye_contours]
           #eye_areas = [cv2.contourArea(eye_contour) for eye_contour in eye_contours]
           #eye_contours = [eye_contour for eye_contour,eye_area in zip(eye_contours,eye_areas) if eye_area > 100]
           #eye_hulls = [cv2.convexHull(eye_contour) for eye_contour in eye_contours]
           #eye_areas = [cv2.contourArea(eye_hull) for eye_hull in eye_hulls]
           #eye_hulls = [eye_hull for eye_hull,eye_area in zip(eye_hulls,eye_areas) if eye_area > 3000 and eye_area < 7000]
           #if eye_hull == []:
           ## 'Most likely a blink.'
           #    eye_hull = np.array([[0,0]])
           #    centroid = eye_data_center[::-1]
           #else:
           #    #eye_hull = eye_hull[eye_areas.index(min(eye_areas))]
           #    M = [cv2.moments(eye_hull) for eye_hull in eye_hulls]
           #    centroids = [[int(m['m10']/m['m00']),int(m['m01']/m['m00'])] if m['m00'] != 0 else [0,0] for m in M]
           #    eye_dist_list = np.sum(np.abs(eye_data_center[::-1] - centroids),1)
           #    centroid = centroids[np.where(eye_dist_list == min(eye_dist_list))[0][0]]
            # crop eye data
	    eye_frame = eye_data[i,eye_data_center[0]-80:eye_data_center[0]+80,eye_data_center[1]-80:eye_data_center[1]+80].copy()
	    # determine location of centroid in cropped data
	    x_offset = (eye_data[0].shape[1] - eye_frame.shape[1])/2
	    y_offset = (eye_data[0].shape[0] - eye_frame.shape[0])/2
            center = (np.array(eye_frame.shape)/2)[::-1]
	    #center = np.array([centroid[0]-x_offset,centroid[1]-y_offset])
	    # threshold the image
	    ret,thresh = cv2.threshold(eye_frame.copy(),44,255,cv2.THRESH_BINARY)
	    # find contours
	    contours,hierarchy = cv2.findContours(thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
	    # find convex hulls
	    hulls = [cv2.convexHull(contour) for contour in contours]
	    # find areas of hulls
	    areas = [cv2.contourArea(hull) for hull in hulls]
	    # filter hulls by area size
	    hulls = [hull for hull,area in zip(hulls,areas) if area > 100 and area < 25000]
	    # filter areas by size
            areas = [area for area in areas if area > 100 and area < 25000]
            # find moments of remaining hulls
	    M = [cv2.moments(hull) for hull in hulls]
	    # find centers of each moment
	    centers = [[int(m['m10']/m['m00']),int(m['m01']/m['m00'])] if m['m00'] != 0 else [0,0] for m in M] 
            # select hull with center that is closest to image center and calculate area
	    dist_list = np.sum(np.abs(centers - center),1)
	    area_trace[i] = areas[np.where(dist_list == min(dist_list))[0][0]]
            raw_pupil_centroid = centers[np.where(dist_list == min(dist_list))[0][0]]
            # store pupil centroid
            centroid_trace[i] = raw_pupil_centroid - center
            centroid_trace[i,1] = -centroid_trace[i,1]
	    # draw pupil contour
	    center_contour = hulls[np.where(dist_list == min(dist_list))[0][0]]
	    center_contour[:,0][:,0] = center_contour[:,0][:,0] + x_offset
	    center_contour[:,0][:,1] = center_contour[:,0][:,1] + y_offset
	    rgb_eye_frame = cv2.cvtColor(eye_data[i].copy(),cv2.COLOR_GRAY2RGB)
	    img = cv2.drawContours(rgb_eye_frame, [center_contour], 0, (0,255,0), 1)
            # draw pupil centroid
            cv2.rectangle(rgb_eye_frame,
	        (raw_pupil_centroid[0]+x_offset - 2, raw_pupil_centroid[1]+y_offset - 2), 
		(raw_pupil_centroid[0]+x_offset + 2, raw_pupil_centroid[1]+y_offset + 2), 
		(0, 255, 0), 
		-1)
            # draw eye contour
            #img = cv2.drawContours(rgb_eye_frame, [eye_hull], 0, (0,128,255), 1)
            # draw eye centroid
            #cv2.rectangle(rgb_eye_frame,(centroid[0] - 2, centroid[1] - 2), (centroid[0] + 2, centroid[1] + 2), (0, 128, 255), -1)            
	    rgb_eye_data[i] = rgb_eye_frame
        
	angular_rotation = np.arcsin((centroid_trace/pixels_per_mm)/r_effective) # trace is in form (Eh, Ev)
       
	np.save(fname + '_area_trace',area_trace)
	np.save(fname + 'raw_xy_position',centroid_trace)
	np.save(fname + 'angular_rotation',angular_rotation)
	tif.imsave(fname + '_tracked.tif',rgb_eye_data)
    else:
        for i in range(eye_data.shape[0]):
	    #crop eye data
	    eye_frame = eye_data[i,eye_data_center[0]-80:eye_data_center[0]+80,eye_data_center[1]-80:eye_data_center[1]+80].copy()
	    # determine location of centroid in cropped data
	    x_offset = (eye_data[0].shape[1] - eye_frame.shape[1])/2
	    y_offset = (eye_data[1].shape[0] - eye_frame.shape[0])/2
            center = (np.array(eye_frame.shape)/2)[::-1]
	    #center = np.array([centroid[0]-x_offset,centroid[1]-y_offset])
	    # threshold the image
	    ret,thresh = cv2.threshold(eye_frame.copy(),44,255,cv2.THRESH_BINARY)
	    # find contours
	    contours, hierarchy = cv2.findContours(thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
	    # find convex hulls
	    hulls = [cv2.convexHull(contour) for contour in contours]
	    # find areas of hulls and filter by size
	    areas = [cv2.contourArea(hull) for hull in hulls]
	    # filter hulls by area size
	    hulls = [hull for hull,area in zip(hulls,areas) if area > 100 and area < 25000]
	    # filter areas by size
            areas = [area for area in areas if area > 100 and area < 25000]
            # find moments of remaining hulls
	    M = [cv2.moments(hull) for hull in hulls]
	    # find centers of each moment
	    centers = [[int(m['m10']/m['m00']),int(m['m01']/m['m00'])] if m['m00'] != 0 else [0,0] for m in M]
	    # select hull with center that is closest to image center and calculate area
	    dist_list = np.sum(np.abs(centers - center),1)
	    area_trace[i] = areas[np.where(dist_list == min(dist_list))[0][0]]
            centroid_trace[i] = centers[np.where(dist_list == min(dist_list))[0][0]] - center
        np.save(fname + '_area_trace',area_trace)
        np.save(fname + '_centroid_position',centroid_trace)
