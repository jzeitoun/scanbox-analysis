import cv2
import numpy as np
import pyfftw
import tifffile as tiff
import sys
import os
import tempfile
import time

from dotdict import dotdict
from sklearn.utils.extmath import cartesian
from sbxread import *

def computeT(tVals):  # think about using concatenate instead of append
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

def align(sbxmap, indices, translations, w=15, template_indices=None, split=True):

    # 1. Data is bidirectional or unidirectional.
    # 2. Data can be single or multi-channel.
    #       - Default aligns only green channel.
    # 2. User can either select template or allow automated selection.
    # 3. If data is multiplaned, select template or allow user to select template.
    #       - If the user wants, split the panes into separate files

    # crop data if bidirectional
    if sbxmap.info['scanmode']: # unidirectional
        margin = 0
        dimensions = (sbxmap.info['length'], sbxmap.info['sz'][0], sbxmap.info['sz'][1])
        plane_dimensions = sbxmap.shape
    else: # bidirectional
        margin = 100
        dimensions[2] = dimensions[2] - 100
        plane_dimensions[2] = plane_dimensions[2] - 100

    # TODO: Allow options for aligning red channel and/or using it to align green.
    # if multichannel, align green channel by default
    input_data_set = sbxmap.data['green']
    if len(sbxmap.channels) > 1:
        channel = '_green'
    else:
        channel = ''

    # check if template is user-selected
    if template_indices == None:
        templates = [input_data[20:40].mean(0)]
        if sbx.num_planes > 1:
            templates = [plane[20:40].mean(0) for plane in input_data.values()]
    else:
        template_indices = slice(template_indices)
        templates = input_data[template_indices].mean(0)
        if sbx.num_planes > 1:
            templates = [plane[template_indices] for plane in input_data.values()]
            # TODO: Allow option to select template by plane.

    # choose whether to split planes
    if split == False:
        output_data_set = np.memmap('moco_aligned_{}{}.sbx'.format(sbxmap.filename, channel),
                                    dtype='uint16',
                                    shape=(dimensions))
        output_data_set = {'plane_{}'.format(i): output_data_set[i::self.num_planes] for i in range(self.num_planes)}
    elif split == True and sbxmap.num_planes > 1:
        output_data_set = {}
        for plane in range(sbxmap.num_planes):
            output_data_set[plane] = np.memmap('moco_aligned_{}{}_plane_{}.sbx'.format(sbxmap.filename, channel, plane),
                                               dtype='uint16',
                                               shape=(plane_dimensions)))

    # prepare template parameters for each plane
    template_params_set = {}
    for template in templates:
        temp = np.zeros([cols+w, rows+w])
        tVals = (ds_template.T - ds_template.mean()) / (ds_template.std() * np.sqrt(2))
        tNew = computeT(tVals)
        newTVals = tVals[::-1,:]
        newTVals = newTVals[:,::-1]
        fft_wrapper_object = pyfftw.builders.fftn(newTVals,s=(cols+w, rows+w))
        ifft_wrapper_object = pyfftw.builders.ifftn(temp,s=(cols+w,rows+w))
        tFFT = fft_wrapper_object()
        tFFT = separate(tFFT)

        template_params_set.update({'plane_{}'.format(i):
                                        dotdict(
                                           template=template
                                           ds_template=ds_template,
                                           tVals=tVals,
                                           fft_wrapper_object=fft_wrapper_object,
                                           ifft_wrapper_object=ifft_wrapper_object,
                                           tFFT=tFFT)
                                        })

    # iterate through each plane and align data
    for plane,tp in template_params.items():
        input_data = input_data[plane]
        output_data = output_data[plane]
        for idx in indices:
            moving = input_data[idx]
            ds_moving = cv2.pyrDown(moving)
            rows, cols = ds_moving.shape

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
            h_gridWidth = grid.shape[0] / 2
            h_gridHeight = grid.shape[1] / 2

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
            xy = 2*xy

            rows, cols = moving.shape
            cx = rows / 250
            cy = cols / 150
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

            newXY = find_z(cx,cy,cart,f_moving,f_template,Lx,Rx,Ly,Ry,xy,xy2,rows,cols)

            translations[idx] = np.int64(newXY)
            M = np.float32([[1,0,newXY[0]],[0,1,newXY[1]]])
            output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))

            if p_num == num_cores:
                norm_idx = idx - idx_range[0] + 1
                if norm_idx % chunk_size == 0:
                    i = norm_idx / chunk_size
                    queue.put(i)
                    if i == 50:
                        queue.put('stop')
