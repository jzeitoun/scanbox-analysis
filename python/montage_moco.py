import cv2
import numpy as np
import pyfftw
import tifffile as tiff
import os
import time
from sklearn.utils.extmath import cartesian

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

# rewrite without loop
def downsample(image):
    rows = image.shape[0]
    cols = image.shape[1]
    dstRows = np.int64(np.floor(image.shape[0]/2))
    dstCols = np.int64(np.floor(image.shape[1]/2))
    ds_image = np.uint16(np.zeros([dstRows,dstCols]))
    for r in range(dstRows):
        for c in range(dstCols):
            row,col = ind2sub(ds_image.shape,(c+dstCols*r))
            a0,a1 = ind2sub(image.shape,(2*c+2*r*cols))
            b0,b1 = ind2sub(image.shape,(2*c+1+2*r*cols))
            c0,c1 = ind2sub(image.shape,(2*c + (2*r+1)*cols))
            d0,d1 = ind2sub(image.shape,(2*c+1 + (2*r+1)*cols))
            ds_image[row,col] = (.25*(np.float64(image[a0,a1]) + np.float64(image[b0,b1]) + np.float64(image[c0,c1]) + np.float64(image[d0,d1])))
    return ds_image

def separate(data):
    a = np.zeros(data.shape[0]*data.shape[1]*2)
    a[::2] = data.flatten().real
    a[1::2] = data.flatten().imag
    a = a.reshape([data.shape[0],2*data.shape[1]])
    return a    

def align(mapped_data,folder,w):

    template = np.mean(~mapped_data[1][19:39], 0)
    ds_template = cv2.pyrDown(template)
    
    rows = ds_template.shape[0]
    cols = ds_template.shape[1]
    
    temp = np.zeros([cols+w,rows+w])
    
    tVals = (ds_template.T - ds_template.mean()) / (ds_template.std() * np.sqrt(2))
    
    tNew = computeT(tVals)
    
    newTVals = tVals[::-1,:]
    newTVals = newTVals[:,::-1]
    fft_wrapper_object = pyfftw.builders.fftn(newTVals,s=(cols+w, rows+w))
    ifft_wrapper_object = pyfftw.builders.ifftn(temp,s=(cols+w,rows+w))
    tFFT = fft_wrapper_object()
    tFFT = separate(tFFT)
    
    transforms = np.zeros([mapped_data[1].shape[0],2])
    memmap_file = samples_name = os.path.join(folder,mapped_data[0])
    aligned_data = np.memmap(memmap_file, dtype='uint16', mode = 'w+', shape=(
                                                                                mapped_data[1].shape[0],
                                                                                mapped_data[1].shape[1],
                                                                                mapped_data[1].shape[2]
                                                                       ))
    
    start = time.time()
    for idx in range(mapped_data[1].shape[0]):
        moving = ~mapped_data[1][idx]
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
        rxb = np.int32(np.rint((rx*rows/cx)+1))
        rxe = np.int32(np.rint((rx+1)*rows/cx))
        ryb = np.int32(np.rint((ry*cols/cy)+1))
        rye = np.int32(np.rint((ry+1)*cols/cy))
        z = np.zeros([3,3])
        
        cart = cartesian([np.arange(-1,2),np.arange(-1,2)])
        xy2 = cart + xy[::-1]
        lessThan = np.int64(xy2 < 0)
        greaterThan = np.int64(xy2 > 0)
        Lx = np.int64(np.maximum(np.tile(rxb,(9,1)),np.tile(np.array([1-lessThan[:,0]*xy2[:,0]]).T,(1,cx))))-1
        Rx = np.int64(np.minimum(np.tile(rxe,(9,1)),np.tile(np.array([rows-greaterThan[:,0]*xy2[:,0]]).T,(1,cx))))
        Ly = np.int64(np.maximum(np.tile(ryb,(9,1)),np.tile(np.array([1-lessThan[:,1]*xy2[:,1]]).T,(1,cy))))-1
        Ry = np.int64(np.minimum(np.tile(rye,(9,1)),np.tile(np.array([cols-greaterThan[:,1]*xy2[:,1]]).T,(1,cy))))
        
        for i in range(9):
            for x in range(cx):
                for y in range(cy):
                    z[tuple(cart[i]+1)] = z[tuple(cart[i]+1)] + np.sum((f_moving[Lx[i,x]:Rx[i,x],Ly[i,y]:Ry[i,y]] - f_template[Lx[i,x]+xy2[i,0]:Rx[i,x]+xy2[i,0],Ly[i,y]+xy2[i,1]:Ry[i,y]+xy2[i,1]])**2)  
         
        for i in range(9):
            z[tuple(cart[i]+1)] = z[tuple(cart[i]+1)]/((rows-np.abs(cart[i,0]+xy[1]))*(cols-np.abs(cart[i,1]+xy[0])))
            
        minIDX = np.array(np.where(z==np.min(z)))
        newXY = np.array([np.arange(-1,2)[minIDX[1]]+xy[0],np.arange(-1,2)[minIDX[0]]+xy[1]]).reshape([2,])
        transforms[idx] = newXY
        M = np.float32([[1,0,newXY[0]],[0,1,newXY[1]]])
        aligned_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))
        
        print 'Aligned frame %d/%d in %s.' % (idx,mapped_data[1].shape[0],mapped_data[0])
    
    print 'Finished aligning %s in %d seconds.' % (mapped_data[0], time.time()-start)    
    return aligned_data