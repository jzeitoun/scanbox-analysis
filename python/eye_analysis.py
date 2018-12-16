import numpy as np
import h5py
import cv2
import tifffile as tif
import math
import os
import sys

# Constants
bounding_region = 30 # Default: 30
thresh_val = 220 # Default: 230
lower_area_limit = 100 # Default: 100
upper_area_limit = 25000 # Default: 25000
circ_score_thresh = 1.55 # Default: 1.55
r_effective = 1.25 # Radius of pupil to center of eyeball

def import_eye(filename):
    '''
    Extracts data from .mat.
    '''
    if '.mat' in filename:
        filename = os.path.splitext(filename)[0]
    data = h5py.File(filename + '.mat')
    eye_data = np.squeeze(np.array(data['data'])).transpose(0,2,1)
    return eye_data

def single_frame_contours(frame, equalize=True):
    '''
    Finds the contour of the pupil in one frame.
    '''
    # Get shape of data
    height, width = frame.shape
    # Calculate coordinates for center of frame
    center = np.array([height, width])/2
    # Calculate coordinates for center of cropped frame
    cropped_center = np.array([bounding_region, bounding_region])/2
    # Generate slices to crop frame

    height_slice = slice(int(center[0]-bounding_region), int(center[0]+bounding_region))
    width_slice = slice(int(center[1]-bounding_region), int(center[1]+bounding_region))
    # Calculate X distance between full frame edge and cropped edge
    x_offset = (width - 2*bounding_region)/2
    # Calculate Y distance between full frame edge and cropped edge
    y_offset = (height - 2*bounding_region)/2
    # Create adaptive histogram equalization params
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))

    if equalize:
        # Apply adaptive histogram equalization
        frame = clahe.apply(frame)

    # Crop frame to restrict pupil search region
    cropped_frame = frame[height_slice, width_slice]
    # Apply threshold to frame
    ret, thresh = cv2.threshold(cropped_frame.copy(), thresh_val, 255, cv2.THRESH_BINARY)
    # Find contours
    _, contours, hierarchy = cv2.findContours(thresh, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    # Find convex hull of each contour
    hulls = [cv2.convexHull(contour) for contour in contours]
    # Find area of each hull
    areas = [cv2.contourArea(hull) for hull in hulls]
    # Filter hulls by area size
    hulls = [hull for hull,area in zip(hulls,areas) if area > 100 and area < 25000]
    # Find moments of remaining hulls
    moments = [cv2.moments(hull) for hull in hulls]
    # Calculate centroid of remaining hulls
    centroids = [[int(m['m10']/m['m00']),int(m['m01']/m['m00'])] if m['m00'] != 0 else [0,0] for m in moments]

    if len(centroids):
        # Select contour with centroid closest to center of frame
        dist_list = np.sum(np.abs(centroids - cropped_center), 1)
        center_contour_index = np.argmin(dist_list)
        center_contour = hulls[center_contour_index]
        center_centroid = centroids[center_contour_index]
        # Correct contour offset
        center_contour[:,0][:,0] = center_contour[:,0][:,0] + x_offset
        center_contour[:,0][:,1] = center_contour[:,0][:,1] + y_offset

        # Calculate circularity score
        center_surround_distances = [
                math.hypot(
                    point[0][0] - center_centroid[0], point[0][1] - center_centroid[1]
                    ) for point in center_contour
                ]
        min_dist = min(center_surround_distances)
        max_dist = max(center_surround_distances)
        circ_score = max_dist/min_dist

        if circ_score > circ_score_thresh:
            return None
        else:
            return center_contour
    else:
        # No contours found, return None
        return None

def all_frame_contours(eye_data, equalize=True):
    '''
    Outputs array containing pupil contour for all frame.
    '''
    # Get shape of data
    depth, height, width = eye_data.shape
    # Create list to hold output
    contour_list = []

    for frame in eye_data:
        contour_list.append(single_frame_contours(frame, equalize))

    return contour_list

def calculate_metrics(contours, center, px_length, mm_length, factor=1):
    '''
    Returns dictionary containing pupil diameter, centroid position,
    angular rotation, angular velocity.
    '''
    mm_per_pixel = mm_length / px_length
    diameters = []
    centroid_position = []

    for contour in contours:
        if not isinstance(contour, type(None)):
            area = cv2.contourArea(contour)
            diameter = np.sqrt((4*area)/np.pi)
            diameters.append(diameter * mm_per_pixel)
            M = cv2.moments(contour)
            centroid = np.array([int(M['m10']/M['m00']), int(M['m01']/M['m00'])])
            centroid_position.append(centroid)
        else:
            centroid_position.append(np.array([np.nan]*2))

    centroid_position = np.array(centroid_position)
    centroid_position_norm = centroid_position - center
    centroid_position_norm_mm = centroid_position_norm * mm_per_pixel

    # Get (Eh,Ev) in radians
    angular_rotation = np.arcsin(centroid_position_norm_mm/r_effective)
    angular_rotation[:,0] *= factor # reverse x coordinates if necessary
    # (Eh,Ev) in degrees
    angular_rotation = np.rad2deg(angular_rotation)

    angular_velocity = np.diff(angular_rotation, axis=0)

    return dict(diameters=diameters,
            centroid_positions=centroid_position_norm_mm,
            angular_rotation=angular_rotation,
            angular_velocity=angular_velocity)

def annotate_eye(eye_data, contours, centroid=True, score=True):
    '''
    Draws contours onto each frame and returns data in RGB format.
    '''
    rgb_eye_data = []
    depth, height, width = eye_data.shape
    for frame, contour in zip(eye_data, contours):
        # Convert to rgb
        rgb_frame = cv2.cvtColor(frame.copy(), cv2.COLOR_GRAY2RGB)
        if not isinstance(contour, np.ndarray):
            rgb_eye_data.append(rgb_frame)
            continue
        # Calculate contour centroid
        M = cv2.moments(contour)
        if M['m00']:
            centroid = [int(M['m10']/M['m00']), int(M['m01']/M['m00'])]
        else:
            centroid = [0, 0]
        # Calculate circularity score
        center_surround_distances = [
                math.hypot(
                    point[0][0] - centroid[0], point[0][1] - centroid[1]
                    ) for point in contour
                ]
        min_dist = min(center_surround_distances)
        max_dist = max(center_surround_distances)
        circ_score = max_dist/min_dist
        color = (0, 255, 0) if circ_score < circ_score_thresh else (255, 0, 0)

        # Draw contour
        img = cv2.drawContours(rgb_frame, [contour], 0, color, 2)

        if centroid:
            # Draw contour centroid
            cv2.rectangle(rgb_frame,
                (centroid[0] - 2, centroid[1] - 2),
                (centroid[0] + 2, centroid[1] + 2),
                color,
                -1)

        if score:
            # Draw circularity score
            font = cv2.FONT_HERSHEY_SIMPLEX
            cv2.putText(rgb_frame, str(circ_score), (10, int(.9*height)), font, 1, color, 2)

        rgb_eye_data.append(rgb_frame)
    return np.array(rgb_eye_data)

def main():
    filename = sys.argv[1]
    basename = os.path.splitext(filename)[0]
    print('Opening eye data...')
    eye_data = import_eye(filename)
    print('Extracting pupil contours...')
    contours = all_frame_contours(eye_data)
    np.save('{}_contours'.format(basename), contours)
    if '-write' in sys.argv:
        print('Annotating data...')
        annotated_data = annotate_eye(eye_data, contours)
        print('Saving annotated data...')
        tif.imsave('{}_annotated.tif'.format(basename), annotated_data)
    print('Finished')

if __name__ == '__main__':
    main()
