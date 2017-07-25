import cv2
import numpy as np
import pyfftw
import tifffile as tiff
import sys
import os
import tempfile
import time

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
    
def ind2sub(array_shape, ind):
    rows = (ind / array_shape[1])
    cols = (ind % array_shape[1]) # or numpy.mod(ind.astype('int'), array_shape[1])
    return (rows, cols)

def separate(data):
    a = np.zeros(data.shape[0]*data.shape[1]*2)
    a[::2] = data.flatten().real
    a[1::2] = data.flatten().imag
    a = a.reshape([data.shape[0],2*data.shape[1]])
    return a    

def find_z(cx,cy,cart,f_moving,f_template,Lx,Rx,Ly,Ry,xy,xy2,rows,cols):
    z = np.zeros([3,3])
    for i in range(9):
        z[tuple(cart[i]+1)] = np.sum((f_moving[Lx[i,0]:Rx[i,-1],Ly[i,0]:Ry[i,-1]] - f_template[Lx[i,0]+xy2[i,0]:Rx[i,-1]+xy2[i,0],Ly[i,0]+xy2[i,1]:Ry[i,-1]+xy2[i,1]])**2)
         
    for i in range(9):
        z[tuple(cart[i]+1)] = z[tuple(cart[i]+1)]/((rows-np.abs(cart[i,0]+xy[1]))*(cols-np.abs(cart[i,1]+xy[0])))

    minIDX = np.array(np.where(z==np.min(z)))
    newXY = np.array([np.arange(-1,2)[minIDX[1]]+xy[0],np.arange(-1,2)[minIDX[0]]+xy[1]]).reshape([2,])
    return newXY

def align_purepy(filename, idx_range, template, length, height, mapped_width, width, transform_file, queue, scanmode, w=15):
    
    mapped_data = sbxmap(filename + '.sbx')

    output_data = np.memmap('Moco_Aligned_' + filename + '.sbx', dtype='uint16', shape=(length, height, width)) 

    transforms = np.memmap(transform_file, dtype='int64', shape =(length,2))
    
    ds_template = cv2.pyrDown(template)
    rows, cols = ds_template.shape
    
    temp = np.zeros([cols+w,rows+w])
    
    tVals = (ds_template.T - ds_template.mean()) / (ds_template.std() * np.sqrt(2))
    
    tNew = computeT(tVals)
    
    newTVals = tVals[::-1,:]
    newTVals = newTVals[:,::-1]
    fft_wrapper_object = pyfftw.builders.fftn(newTVals,s=(cols+w, rows+w))
    ifft_wrapper_object = pyfftw.builders.ifftn(temp,s=(cols+w,rows+w))
    tFFT = fft_wrapper_object()
    tFFT = separate(tFFT)
    
    for idx in idx_range:
        moving = mapped_data[idx]
        # need to crop left margin if data is bidirectional
        if scanmode == 0:
            moving = moving[:,100:]
        ds_moving = cv2.pyrDown(moving)
        rows = ds_moving.shape[0]
        cols = ds_moving.shape[1]

        aVals = (ds_moving.T - ds_moving.mean()) / (ds_moving.std() * np.sqrt(2))
        aNew = computeT(aVals)
        aFFT = fft_wrapper_object(aVals)
        aFFT = separate(aFFT)
        out = np.zeros([tFFT.shape[0],tFFT.shape[1]])
        out[:,::2] = tFFT[:,::2]*aFFT[:,::2] - tFFT[:,1::2]*aFFT[:,1::2]
        out[:,1::2] = tFFT[:,::2]*aFFT[:,1::2] + tFFT[:,1::2]*aFFT[:,::2]
        out = out.flatten()[::2]+1j*out.flatten()[1::2]
        out = out.reshape([cols+w,rows+w])
        out = ifft_wrapper_object(out)
        b = out.real
        
        ########################################################################################
        grid = np.zeros([(rows+w)-(rows-w-1),(cols+w)-(cols-w-1)])
        h_gridWidth = grid.shape[0]/2
        h_gridHeight = grid.shape[1]/2
        
        r1 = np.arange(rows-w-1,rows-1)
        c1 = np.arange(cols-w-1,cols-1)
        grid[:h_gridHeight,:h_gridWidth] = (aNew[3][cols-w-1:cols-1,rows-w-1:rows-1] + tNew[0][cols-w-1:cols-1,rows-w-1:rows-1] - 2*(b[cols:cols+w,rows:rows+w])[::-1,::-1])/(np.outer(c1,r1))
        
        r2 = np.arange(2*rows-(rows+w-1),2*rows-(rows-2))
        c2 = np.arange(cols-w-1,cols-1)
        grid[:h_gridHeight,h_gridWidth:] = ((aNew[2][cols-w-1:cols-1,rows-w-1:rows])[:,::-1] + (tNew[1][cols-w-1:cols-1,rows-w-1:rows])[:,::-1] - 2*(b[cols:cols+w,rows-w-1:rows])[::-1,::-1])/(np.outer(c2,r2[::-1]))
        
        r3 = np.arange(rows-w-1,rows-1)
        c3 = np.arange(2*cols-(cols+w-1),2*cols-(cols-2))
        grid[h_gridHeight:,:h_gridWidth] = ((aNew[1][cols-w-1:cols,rows-w-1:rows-1])[::-1,:] + (tNew[2][cols-w-1:cols,rows-w-1:rows-1])[::-1,:] - 2*(b[cols-w-1:cols,rows:rows+w])[::-1,::-1])/(np.outer(c3[::-1],r3))
        
        r4 = np.arange(2*rows-(rows+w-1),2*rows-(rows-2))
        c4 = np.arange(2*cols-(cols+w-1),2*cols-(cols-2))
        grid[h_gridHeight:,h_gridWidth:] = ((aNew[0][cols-w-1:cols,rows-w-1:rows])[::-1,::-1] + (tNew[3][cols-w-1:cols,rows-w-1:rows])[::-1,::-1] - 2*(b[cols-w-1:cols,rows-w-1:rows])[::-1,::-1])/(np.outer(c4[::-1],r4[::-1]))
        ##########################################################################################
        
        r_range = np.arange(rows-w-1,rows+w)
        c_range = np.arange(cols-w-1,cols+w)
        
        minIDX = np.where(grid==np.min(grid))
        xy = np.array([c_range[minIDX[0]]-(cols-1),r_range[minIDX[1]]-(rows-1)]).reshape([2,])
        
        f_moving = np.float64(moving)
        f_template = np.float64(template)
        xy = 2*xy
        
        rows = moving.shape[0]
        cols = moving.shape[1]
        cx = rows/250
        cy = cols/150
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
        
        transforms[idx] = np.int64(newXY)
        M = np.float32([[1,0,newXY[0]],[0,1,newXY[1]]])
        output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))
        queue.put(idx+1)
        
