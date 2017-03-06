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
    if write:
        rgb_eye_data = np.uint8(np.zeros([eye_data.shape[0],eye_data.shape[1],eye_data.shape[2],3]))
	for i in range(eye_data.shape[0]):
            # crop eye data
	    eye_frame = eye_data[i,eye_data_center[0]-80:eye_data_center[0]+80,eye_data_center[1]-80:eye_data_center[1]+80].copy()
	    # determine cropped center
	    center = np.array(eye_frame.shape)/2
	    x_offset = (eye_data[0].shape[1] - eye_frame.shape[1])/2
	    y_offset = (eye_data[0].shape[0] - eye_frame.shape[0])/2
	    # threshold the image
	    ret,thresh = cv2.threshold(eye_frame.copy(),44,255,cv2.THRESH_BINARY)
	    # find contours
	    contours, hierarchy = cv2.findContours(thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
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
	    # draw contour onto data
	    center_contour = hulls[np.where(dist_list == min(dist_list))[0][0]]
	    center_contour[:,0][:,0] = center_contour[:,0][:,0] + x_offset
	    center_contour[:,0][:,1] = center_contour[:,0][:,1] + y_offset
	    rgb_eye_frame = cv2.cvtColor(eye_data[i].copy(),cv2.COLOR_GRAY2RGB)
	    img = cv2.drawContours(rgb_eye_frame, [center_contour], 0, (0,255,0), 3)
	    rgb_eye_data[i] = rgb_eye_frame
        np.save(fname + '_area_trace',area_trace)
        tif.imsave(fname + '_tracked.tif',rgb_eye_data)
    else:
        for i in range(eye_data.shape[0]):
	    #crop eye data
	    eye_frame = eye_data[i,eye_data_center[0]-80:eye_data_center[0]+80,eye_data_center[1]-80:eye_data_center[1]+80].copy()
	    # determine cropped center
	    center = np.array(eye_frame.shape)/2
	    x_offset = (eye_data[0].shape[1] - eye_frame.shape[1])/2
	    y_offset = (eye_data[1].shape[0] - eye_frame.shape[0])/2
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
        np.save(fname + '_area_trace',area_trace)
