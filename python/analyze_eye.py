import numpy as np
import h5py
import cv2
import tifffile as tif
import math
import os
import sys

# Constants
#bounding_region = 25
#thresh_val = 240

def analyze_eye(filename, bounding_region=25, thresh_val=240, pixels_per_mm=195.0/4, eye='left', write=0):
    '''
    Calculates pupil area and angular rotation  and saves data as .npy file.
    If write = 1, will also write out data with tracked pupil.
    '''
    # restricts pupil search to +/- this value from the center
    #if 'eye2' in filename:
    #    #bounding_region = 25
    #    #thresh_val = 75
    #    #thresh_val = 200
    #    factor = -1
    #    pixels_per_mm = 195.0/4
    #else:
    #    #bounding_region = 25
    #    #thresh_val = 44
    #    #thresh_val = 240
    #    factor = 1
    #    pixels_per_mm = 138.0/4

    factor = -1 if eye == 'left' else 1
    r_effective = 1.25 # radius of pupil to center of eyeball
    print 'Using threshold value of: ', thresh_val

    # read in eye data
    if '.mat' in filename:
        filename = filename[:-4]
    data = h5py.File(filename + '.mat')
    eye_data = np.squeeze(np.array(data['data'])).transpose(0,2,1)
    depth,rows,cols = eye_data.shape

    eye_data_center = np.array(eye_data.shape[1:])/2 # find center of entire frame
    area_trace = np.zeros(eye_data.shape[0]) # pupillary area in mm^2
    centroid_trace = np.zeros([eye_data.shape[0],2],dtype='int64') # position of centroid in xy coordinates
    raw_pos_trace = centroid_trace.copy()
    x_offset = (eye_data.shape[2] - 2*bounding_region)/2 # x distance between full frame edge and cropped edge
    y_offset = (eye_data.shape[1] - 2*bounding_region)/2 # y distance between full frame edge and cropped edge
    center = np.array([bounding_region,bounding_region]) # center of cropped data

    # create adaptive histogram equalization params
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))

    circ_score_list = []
    bad_count = 0

    if write:
        rgb_eye_data = tif.tifffile.memmap(filename + '_tracked.tif', dtype='uint8', shape=(depth,rows,cols,3))
        #rgb_eye_data = np.zeros([eye_data.shape[0],eye_data.shape[1],eye_data.shape[2],3],dtype='uint8')
        for i in range(eye_data.shape[0]):
            # apply adaptive histogram equalization
            eye_frame_full = clahe.apply(eye_data[i])
            # crop eye data
            eye_frame = eye_frame_full[
                eye_data_center[0]-bounding_region:eye_data_center[0]+bounding_region,
                eye_data_center[1]-bounding_region:eye_data_center[1]+bounding_region].copy()

            # threshold the image
            ret,thresh = cv2.threshold(eye_frame.copy(),thresh_val,255,cv2.THRESH_BINARY)
            # find contours
            _,contours,hierarchy = cv2.findContours(thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
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

            if centers != []:
                dist_list = np.sum(np.abs(centers - center),1)

                raw_pupil_centroid = centers[np.where(dist_list == min(dist_list))[0][0]]

                # store pupil centroid
                centroid_trace[i] = raw_pupil_centroid - center
                centroid_trace[i,1] = -centroid_trace[i,1]

                # select center contour
                center_contour = hulls[np.where(dist_list == min(dist_list))[0][0]]

                # calculate circularity score
                center_surround_distances = [math.hypot(point[0][0] - raw_pupil_centroid[0],point[0][1] - raw_pupil_centroid[1]) for point in center_contour]
                min_dist = min(center_surround_distances)
                max_dist = max(center_surround_distances)
                circ_score = max_dist/min_dist
                circ_score_list.append(circ_score)

                # if score is bad
                if circ_score > 1.5:
                    color = (255,0,0)
                    centroid_trace[i] = centroid_trace[i-1]
                    raw_pos_trace[i] = raw_pos_trace[i-1]
                    # exclude value from pupil size trace
                    area_trace[i] = np.nan
                    bad_count += 1
                # if score is good
                else:
                    color = (0,255,0)
                    centroid_trace[i] = raw_pupil_centroid - center
                    raw_pos_trace[i,0] = raw_pupil_centroid[0]+x_offset
                    raw_pos_trace[i,1] = raw_pupil_centroid[1]+y_offset
                    area_trace[i] = areas[np.where(dist_list == min(dist_list))[0][0]]

                # offset contour to place in middle of frame
                center_contour[:,0][:,0] = center_contour[:,0][:,0] + x_offset
                center_contour[:,0][:,1] = center_contour[:,0][:,1] + y_offset

                # convert eye frame to rgb
                rgb_eye_frame = cv2.cvtColor(eye_frame_full.copy(),cv2.COLOR_GRAY2RGB)

                # draw pupil contour
                img = cv2.drawContours(rgb_eye_frame, [center_contour], 0, color, 2)

                # draw pupil centroid
                cv2.rectangle(rgb_eye_frame,
                    (raw_pupil_centroid[0]+x_offset - 2, raw_pupil_centroid[1]+y_offset - 2),
                    (raw_pupil_centroid[0]+x_offset + 2, raw_pupil_centroid[1]+y_offset + 2),
                    color,
                    -1)

                # stamp circularity score
                font = cv2.FONT_HERSHEY_SIMPLEX
                cv2.putText(rgb_eye_frame,str(circ_score),(10, int(.9*rows)), font, 1, color, 2)

                rgb_eye_data[i] = rgb_eye_frame

            # if no contour found, fill with last value
            else:
                # forward fill
                centroid_trace[i] = centroid_trace[i-1]
                raw_pos_trace[i] = raw_pos_trace[i-1]
                # exclude value from pupil size trace
                area_trace[i] = np.nan
                bad_count += 1
                rgb_eye_frame = cv2.cvtColor(eye_data[i].copy(),cv2.COLOR_GRAY2RGB)
                color = (255,255,255)
                # convert eye frame to rgb
                rgb_eye_frame = cv2.cvtColor(eye_frame_full.copy(),cv2.COLOR_GRAY2RGB)
                # draw pupil contour
                img = cv2.drawContours(rgb_eye_frame, [center_contour], 0, color, 2)
                # draw pupil centroid
                cv2.rectangle(rgb_eye_frame,
                    (raw_pupil_centroid[0]+x_offset - 2, raw_pupil_centroid[1]+y_offset - 2),
                    (raw_pupil_centroid[0]+x_offset + 2, raw_pupil_centroid[1]+y_offset + 2),
                    color,
                    -1)
                # stamp circularity score
                font = cv2.FONT_HERSHEY_SIMPLEX
                cv2.putText(rgb_eye_frame,str(circ_score),(10,200), font, 1, color, 2)

                rgb_eye_data[i] = rgb_eye_frame

        print 'Bad Counts:', bad_count
        angular_rotation = np.zeros(centroid_trace.shape)
        angular_rotation[:,0] = np.arcsin((centroid_trace[:,0]/pixels_per_mm)/r_effective) * factor # Eh in radians
        angular_rotation[:,1] = np.arcsin((centroid_trace[:,1]/pixels_per_mm)/r_effective) # Ev in radians
        angular_rotation = np.rad2deg(angular_rotation) # (Eh,Ev) into degrees

        raw_pos_trace = [[eye_data.shape[1],eye_data.shape[2]],raw_pos_trace]

        np.save(filename + '_circ_score',circ_score_list)
        np.save(filename + '_pupil_area',area_trace)
        np.save(filename + '_raw_xy_position', raw_pos_trace)
        np.save(filename + '_angular_rotation',angular_rotation)
        #tif.imsave(filename + '_tracked.tif', rgb_eye_data)

    else:
        for i in range(eye_data.shape[0]):
            # crop eye data
            eye_frame = eye_data[i,
                eye_data_center[0]-bounding_region:eye_data_center[0]+bounding_region,
                eye_data_center[1]-bounding_region:eye_data_center[1]+bounding_region].copy()
            # threshold the image
            ret,thresh = cv2.threshold(eye_frame.copy(),thresh_val,255,cv2.THRESH_BINARY)
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
            if centers != []:
                dist_list = np.sum(np.abs(centers - center),1)
                area_trace[i] = areas[np.where(dist_list == min(dist_list))[0][0]]
                raw_pupil_centroid = centers[np.where(dist_list == min(dist_list))[0][0]]

                # store pupil centroid
                centroid_trace[i] = raw_pupil_centroid - center
                centroid_trace[i,1] = -centroid_trace[i,1]

                # select center contour
                center_contour = hulls[np.where(dist_list == min(dist_list))[0][0]]

                # calculate circularity score
                center_surround_distances = [math.hypot(point[0][0] - raw_pupil_centroid[0],point[0][1] - raw_pupil_centroid[1]) for point in center_contour]
                min_dist = min(center_surround_distances)
                max_dist = max(center_surround_distances)
                circ_score = max_dist/min_dist
                circ_score_list.append(circ_score)

                # if score is bad
                if circ_score > 1.25:
                    centroid_trace[i] = centroid_trace[i-1]
                    raw_pos_trace[i] = raw_pos_trace[i-1]
                    # exclude value from pupil size trace
                    area_trace[i] = np.nan
                    bad_count += 1
                # if score is good
                else:
                    centroid_trace[i] = raw_pupil_centroid - center
                    raw_pos_trace[i,0] = raw_pupil_centroid[0]+x_offset
                    raw_pos_trace[i,1] = raw_pupil_centroid[1]+y_offset
                    area_trace[i] = areas[np.where(dist_list == min(dist_list))[0][0]]
            # if no contour found, fill with last value
            else:
                # forward fill
                centroid_trace[i] = centroid_trace[i-1]
                raw_pos_trace[i,0] = raw_pos_trace[i-1,0]
                raw_pos_trace[i,1] = raw_pos_trace[i-1,1]
                # exclude value from pupil size trace
                area_trace[i] = np.nan
                bad_count += 1

        print 'Bad Counts:',bad_count
        angular_rotation = np.zeros(centroid_trace.shape)
        angular_rotation[:,0] = np.arcsin((centroid_trace[:,0]/pixels_per_mm)/r_effective) * factor # Eh in radians
        angular_rotation[:,1] = np.arcsin((centroid_trace[:,1]/pixels_per_mm)/r_effective) # Ev in radians
        angular_rotation = np.rad2deg(angular_rotation) # (Eh,Ev) into degrees

        # include frame dimensions in raw trace data
        raw_pos_trace = [[eye_data.shape[1],eye_data.shape[2]],raw_pos_trace]

        np.save(filename + '_pupil_area',area_trace)
        np.jksave(filename + '_raw_xy_position', raw_pos_trace)
        np.save(filename + '_norm_xy_position',centroid_trace)
        np.save(filename + '_angular_rotation',angular_rotation)

        return area_trace,angular_rotation

def main():
    if 'write' in sys.argv:
        analyze_eye(sys.argv[1], sys.argv[2])
    else:
        analyze_eye(sys.argv[1])

if __name__ == '__main__':
    main()
