import numpy as np
import cv2
import json

import sys

from sbxmap import sbxmap
from statusbar import Statusbar

def load_rois(filename):
    with open(filename, 'r') as f:
        rois = json.load(f)
    return rois

def polygon_to_array(polygon):
    points = np.int64(polygon.split(','))
    num_points = len(points)
    point_pairs = np.array(
            [
                [points[i], points[i+1]
                    ] for i in range(0, num_points, 2)]
            )
    return point_pairs

def extract_mean_trace(data, point_pairs):
    x,y,w,h = cv2.boundingRect(point_pairs)
    offset = np.array((x,y))
    mask_pairs = point_pairs - offset
    bbox = np.zeros((h,w))
    bbox_mask = cv2.fillPoly(bbox, [mask_pairs], (255,255,255)) == 0
    bbox_full_mask = np.broadcast_to(bbox_mask, (data.shape[0], bbox_mask.shape[0], bbox_mask.shape[1]))
    masked_data = np.ma.array(data[:,y:y+h,x:x+w], mask=bbox_full_mask)
    trace = masked_data.mean(axis=(1,2))
    return trace

def main():
    sbx = sbxmap(sys.argv[1])

    with open(sys.argv[2], 'r') as f:
        rois = json.load(f)

    print('Extracting traces...')

    num_tasks = len(sbx.channels) * len(rois)
    status = Statusbar(num_tasks=num_tasks)
    i = 0
    status.initialize()

    for channel in sbx.channels:
        data = sbx.data()[channel]['plane_0']
        for roi in rois:
            point_pairs = polygon_to_array(roi['polygon'])
            trace = extract_mean_trace(data, point_pairs)
            roi.update({channel:trace.data.tolist()})
            i += 1
            status.update(i)

    print('\nSaving data...')
    with open(sys.argv[2], 'w') as f:
        json.dump(rois, f)

    print('Done.')

if __name__ == '__main__':
    main()
