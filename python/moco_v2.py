import cv2
import numpy as np
import scipy.io as spio
import pyfftw
import tifffile as tiff
import sys
import os
import tempfile
import time

from setproctitle import setproctitle
from dotdict import dotdict
import loadmat as lmat
from sklearn.utils.extmath import cartesian

import globe
from sbxmap import sbxmap

def computeT(tVals):
    t = tVals**2
    a = t.cumsum(0).cumsum(1)
    b = t[:,::-1].cumsum(0).cumsum(1)
    c = t[::-1,:].cumsum(0).cumsum(1)
    d = t[::-1].cumsum(0).cumsum(1)
    T = (np.concatenate((a,b,c,d))).reshape([4,t.shape[0],t.shape[1]])
    return T

def separate(data):
    a = np.zeros(data.shape[0]*data.shape[1]*2)
    a[::2] = data.flatten().real
    a[1::2] = data.flatten().imag
    a = a.reshape([data.shape[0],2*data.shape[1]])
    return a

def find_z(cx, cy, cart, f_moving, f_template, Lx, Rx, Ly, Ry, xy, xy2, rows, cols):
    z = np.zeros([3,3])
    for i in range(9):
        z[tuple(cart[i]+1)] = np.sum(
                                (f_moving[Lx[i,0]:Rx[i,-1], Ly[i,0]:Ry[i,-1]] - f_template[Lx[i,0] + xy2[i,0]:Rx[i,-1] + xy2[i,0], Ly[i,0] + xy2[i,1]:Ry[i,-1] + xy2[i,1]])**2
                                )

    for i in range(9):
        z[tuple(cart[i]+1)] = z[tuple(cart[i]+1)] / ((rows-np.abs(cart[i,0]+xy[1])) * (cols-np.abs(cart[i,1] + xy[0])))

    minIDX = np.array(np.where(z==np.min(z)))
    newXY = np.array([np.arange(-1,2)[minIDX[1]] + xy[0], np.arange(-1,2)[minIDX[0]] + xy[1]]).reshape([2,])
    return newXY

def validate_range(indices, max_idx):
    mask = indices < max_idx
    return indices[mask]


def apply_plane_translations(source_name, sink_name, channel, plane_to_align, align_plane, translations):
    '''
    Apply the translations from one plane to another plane. Sink name must be a
    single plane.
    '''
    source = sbxmap(source_name)
    if not source.info['scanmode']:
        margin = 100
    else:
        margin = 0

    sink = sbxmap(sink_name)

    plane_translations = translations['plane_' + align_plane]
    input_data = source.data()[channel]['plane_' + plane_to_align][:,:,margin:]
    output_data = sink.data()[channel]['plane_0']
    for idx in range(input_data.shape[0]):
        moving = input_data[idx]
        rows,cols = moving.shape
        s,x,y = plane_translations[idx]
        M = np.float32([[1,0,x], [0,1,y]])
        output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving), M, (cols,rows)))
        yield idx

def apply_translations(sink_name, source_name, cur_plane, channel, indices):
    # When running this script, it is assumed there is a global variable that contains
    # the translations to be applied (globe.translations).
    source = sbxmap(source_name)
    if not source.info['scanmode']:
        margin = 100
    else:
        margin = 0

    sink = sbxmap(sink_name)
    if cur_plane == 'all':
        planes = ['plane_{}'.format(i) for i in range(source.num_planes)]
    else:
        planes = [cur_plane]


    for plane in planes:
        plane_translations = globe.translations[plane]
        input_data = source.data()[channel][plane][:,:,margin:]
        output_data = sink.data()[channel][plane] if cur_plane == 'all' else sink.data()[channel]['plane_0']
        indices = validate_range(indices, input_data.shape[0])
        for idx in indices:
            moving = input_data[idx]
            rows,cols = moving.shape
            s,x,y = plane_translations[idx]
            M = np.float32([[1,0,x], [0,1,y]])
            output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving), M, (cols,rows)))


def align(source_name, sink_name, templates, cur_plane, channel, indices, w=15):
#def align(channel, indices, w=15):
    # "globe" is just a blank module that holds global variables (source, sink, templates, translations)

    source = sbxmap(source_name)
    if not source.info['scanmode']:
        margin = 100
    else:
        margin = 0

    sink = sbxmap(sink_name)
    if cur_plane == 'all':
        planes = ['plane_{}'.format(i) for i in range(source.num_planes)]
    else:
        planes = [cur_plane]

    setproctitle('moco-sub')

    # prepare template parameters for each plane
    template_params_set = {}
    #for plane, template in templates[channel].items():
    for plane in planes:
        template = templates[channel][plane]
        ds_template = cv2.pyrDown(template)
        rows, cols = ds_template.shape
        temp = np.zeros([cols+w, rows+w])
        ds_template_mean = ds_template.mean()
        if ds_template_mean == 0:
            print('All template frames are blank. Please select new indices for template.')
            return
        tVals = (ds_template.T - ds_template.mean()) / (ds_template.std() * np.sqrt(2))
        tNew = computeT(tVals)
        newTVals = tVals[::-1,:]
        newTVals = newTVals[:,::-1]
        fft_wrapper_object = pyfftw.builders.fftn(newTVals,s=(cols+w, rows+w))
        ifft_wrapper_object = pyfftw.builders.ifftn(temp,s=(cols+w,rows+w))
        tFFT = fft_wrapper_object()
        tFFT = separate(tFFT)

        template_params_set.update({plane:
                                        dotdict(
                                           template=template,
                                           ds_template=ds_template,
                                           tVals=tVals,
                                           tNew=tNew,
                                           fft_wrapper_object=fft_wrapper_object,
                                           ifft_wrapper_object=ifft_wrapper_object,
                                           tFFT=tFFT)
                                        })

    # iterate through each plane and align data
    for plane,tp in template_params_set.items():
        input_data = source.data()[channel][plane][:,:,margin:]
        output_data = sink.data()[channel][plane] if cur_plane == 'all' else sink.data()[channel]['plane_0']
        plane_translations = globe.translations[plane]
        indices = validate_range(indices, input_data.shape[0])
        for idx in indices:
            moving = input_data[idx]
            # Check for blank frams
            if moving.max() == 0:
                print('Frame {} is blank. Skipping frame.'.format(idx))
                continue
            ds_moving = cv2.pyrDown(moving)
            rows,cols = ds_moving.shape

            aVals = (ds_moving.T - ds_moving.mean()) / (ds_moving.std() * np.sqrt(2))
            aNew = computeT(aVals)
            aFFT = tp.fft_wrapper_object(aVals)
            aFFT = separate(aFFT)
            out = np.zeros([tp.tFFT.shape[0], tp.tFFT.shape[1]])
            out[:,::2] = tp.tFFT[:,::2] * aFFT[:,::2] - tp.tFFT[:,1::2] * aFFT[:,1::2]
            out[:,1::2] = tp.tFFT[:,::2] * aFFT[:,1::2] + tp.tFFT[:,1::2] * aFFT[:,::2]
            out = out.flatten()[::2]+1j * out.flatten()[1::2]
            out = out.reshape([cols+w, rows+w])
            out = tp.ifft_wrapper_object(out)
            b = out.real

            grid = np.zeros([(rows+w) - (rows-w-1), (cols+w) - (cols-w-1)])
            h_gridWidth = grid.shape[0] // 2
            h_gridHeight = grid.shape[1] // 2

            r1 = np.arange(rows-w-1, rows-1)
            c1 = np.arange(cols-w-1, cols-1)
            grid[:h_gridHeight, :h_gridWidth] = (aNew[3][cols-w-1:cols-1,rows-w-1:rows-1] + tp.tNew[0][cols-w-1:cols-1,rows-w-1:rows-1] - 2*(b[cols:cols+w,rows:rows+w])[::-1,::-1])/(np.outer(c1,r1))

            r2 = np.arange(2*rows-(rows+w-1), 2*rows-(rows-2))
            c2 = np.arange(cols-w-1, cols-1)
            grid[:h_gridHeight, h_gridWidth:] = ((aNew[2][cols-w-1:cols-1,rows-w-1:rows])[:,::-1] + (tp.tNew[1][cols-w-1:cols-1,rows-w-1:rows])[:,::-1] - 2*(b[cols:cols+w,rows-w-1:rows])[::-1,::-1])/(np.outer(c2,r2[::-1]))

            r3 = np.arange(rows-w-1, rows-1)
            c3 = np.arange(2*cols-(cols+w-1), 2*cols-(cols-2))
            grid[h_gridHeight:, :h_gridWidth] = ((aNew[1][cols-w-1:cols,rows-w-1:rows-1])[::-1,:] + (tp.tNew[2][cols-w-1:cols,rows-w-1:rows-1])[::-1,:] - 2*(b[cols-w-1:cols,rows:rows+w])[::-1,::-1])/(np.outer(c3[::-1],r3))

            r4 = np.arange(2*rows-(rows+w-1), 2*rows-(rows-2))
            c4 = np.arange(2*cols-(cols+w-1), 2*cols-(cols-2))
            grid[h_gridHeight:, h_gridWidth:] = ((aNew[0][cols-w-1:cols,rows-w-1:rows])[::-1,::-1] + (tp.tNew[3][cols-w-1:cols,rows-w-1:rows])[::-1,::-1] - 2*(b[cols-w-1:cols,rows-w-1:rows])[::-1,::-1])/(np.outer(c4[::-1],r4[::-1]))

            r_range = np.arange(rows-w-1, rows+w)
            c_range = np.arange(cols-w-1, cols+w)

            minIDX = np.where(grid==np.min(grid))
            xy = np.array([c_range[minIDX[0]]-(cols-1), r_range[minIDX[1]]-(rows-1)]).reshape([2,])

            f_moving = np.float64(moving)
            f_template = np.float64(template)
            xy = 2 * xy

            rows, cols = moving.shape
            cx = rows // 250
            cx = 1 if cx < 1 else cx
            cy = cols // 150
            rx = np.float64(np.arange(cx))
            ry = np.float64(np.arange(cy))
            rxb = np.rint((rx*rows/cx)+1)
            rxe = np.rint((rx+1)*rows/cx)
            ryb = np.rint((ry*cols/cy)+1)
            rye = np.rint((ry+1)*cols/cy)

            cart = cartesian([np.arange(-1,2),np.arange(-1,2)])
            xy2 = cart + xy[::-1]
            lessThan = np.int64(xy2 < 0)
            greaterThan = np.int64(xy2 > 0)
            Lx = np.int64(np.maximum(np.tile(rxb,(9,1)),np.tile(np.array([1-lessThan[:,0]*xy2[:,0]]).T,(1,cx))))-1
            Rx = np.int64(np.minimum(np.tile(rxe,(9,1)),np.tile(np.array([rows-greaterThan[:,0]*xy2[:,0]]).T,(1,cx))))
            Ly = np.int64(np.maximum(np.tile(ryb,(9,1)),np.tile(np.array([1-lessThan[:,1]*xy2[:,1]]).T,(1,cy))))-1
            Ry = np.int64(np.minimum(np.tile(rye,(9,1)),np.tile(np.array([cols-greaterThan[:,1]*xy2[:,1]]).T,(1,cy))))

            newX, newY = find_z(cx,cy,cart,f_moving,f_template,Lx,Rx,Ly,Ry,xy,xy2,rows,cols)
            plane_translations[idx] = ['applied', newX, newY]
            M = np.float32([[1,0,newX],[0,1,newY]])
            output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))
