import cv2
import numpy as np
import matplotlib.pyplot as plt
import tifffile as tif

import os
import sys

cmap = {
        0.03 : (255,255,0), # yellow
        0.06 : (0,204,0), # dark green
        0.12 : (0,255,255), # light blue
        0.24 : (255,102,0), # dark orange
        0.48 : (255,0,255) # magenta
        }

def gen_mask(radius):
    x,y = np.mgrid[-radius:radius+1,-radius:radius+1]
    mask = x**2 + y**2 <= radius**2
    return mask

def gen_cmap(image, roi_file, radius=3):
    rois = np.load(roi_file).tolist()
    img = plt.imread(image)
    rows, cols = img.shape
    rgb_img = cv2.cvtColor(img, cv2.COLOR_GRAY2RGB)
    cmask = gen_mask(radius)

    for roi in rois['significant_rois']:
        row,col = roi[2]['y'], roi[2]['x']
        bbox = rgb_img[row-radius:row+radius+1,col-radius:col+radius+1,:]
        bbox[cmask] = cmap[roi[1]]

    for roi in rois['non_significant_rois']:
        row,col = roi[2]['y'], roi[2]['x']
        bbox = rgb_img[row-radius:row+radius+1,col-radius:col+radius+1,:]
        bbox[cmask] = (255,255,255) # white

    filename = os.path.splitext(roi_file)[0]
    tif.imsave(filename + '_cmap.tif', rgb_img)

if __name__ == '__main__':
    gen_cmap(sys.argv[1], sys.argv[2])





