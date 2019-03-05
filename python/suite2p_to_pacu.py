#! /usr/bin/python

import numpy as np
import cv2
import json
import os
import sys

import loadmat as lmat

def polygons_to_json(polygons):
    json = {'rois':[]}
    for i, poly in enumerate(polygons):
        points = [{'y': point[0], 'x': point[1]} for point in poly]
        json['rois'].append(
            {'attrs': {
                'neuropil_factor': 0.7,
                'polygon': points,
                'neuropil_polygon': [],
                'neuropil_enabled': False,
                'params': {'cell_id': str(i)},
                'neuropil_ratio': 4.0,
                },
            'id': i
            }
        )
    return json

def convert_to_hull(roi):
    frame = np.zeros([563,425],dtype='uint8')
    coords = zip(roi.y-1,roi.x-1)
    for coord in coords:
        frame[coord] = 255
    contours,_ = cv2.findContours(frame,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
    hull = [cv2.convexHull(c) for c in contours][0]
    return hull

def main():
    filename = sys.argv[1]
    basename= os.path.splitext(filename)[0]
    rois = lmat.loadmat(filename)['acceptedROIs']
    polygons = map(convert_to_hull, rois)
    raw_polygons = [np.int64(np.squeeze(p)) for p in polygons]
    json_out = polygons_to_json(raw_polygons)
    with open('{}_suite2p-rois.json'.format(basename), 'w') as f:
        f.writelines(json.dumps(json_out))


if __name__ == '__main__':
    main()

