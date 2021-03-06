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

def apply_translations(sbx, translations_filename, channel, indices, dimensions, plane_dimensions, split=True):
    input_data_set = sbx.data()[channel]
    translations = np.load(translations_filename + '.npy').tolist()

    # crop data if bidirectional
    if sbx.info['scanmode']: # unidirectional
        margin = 0
    else: # bidirectional
        margin = 100

    # map output files
    if split == False or sbx.num_planes == 1:
        filename = 'moco_aligned_{}_{}.sbx'.format(sbx.filename, channel)
        mode = 'r+' if os.path.exists(filename) else 'w+'
        output_data_set = np.memmap(filename,
                                    dtype='uint16',
                                    shape=(dimensions),
                                    mode=mode)
        output_data_set = {'plane_{}'.format(i): output_data_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    elif split == True:
        output_data_set = {}
        for plane in range(sbx.num_planes):
            filename = 'moco_aligned_{}_{}_plane_{}.sbx'.format(sbx.filename, channel, plane)
            mode = 'r+' if os.path.exists(filename) else 'w+'
            output_data_set.update({'plane_{}'.format(plane):np.memmap(filename,
                                                                       dtype='uint16',
                                                                       shape=(plane_dimensions),
                                                                       mode=mode)
                                                                       })
    for plane, plane_translations in translations.items():
        input_data = input_data_set[plane]
        output_data = output_data_set[plane]
        indices = validate_range(indices, input_data.shape[0])
        for idx in indices:
            moving = input_data[idx,:,margin:]
            rows,cols = moving.shape
            _,x,y = plane_translations[idx]
            M = np.float32([[1,0,x],[0,1,y]])
            output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))


def align(
        sbx, channel='green', w=15, translations=None,
        indices=None, templates=None, template_indices=None,
        split=True, savemat=True):

    # 1. Data is bidirectional or unidirectional.
    # 2. Data can be single or multi-channel.
    #       - Default aligns only green channel.
    # 2. User can either select template or allow automated selection.
    # 3. If data is multiplaned, select template or allow user to select template.
    #       - If the user wants, split the panes into separate files

    setproctitle('moco-sub')

    if isinstance(indices, type(None)):
        indices = range(sbx.shape[0])

    # crop data if bidirectional
    margin = 0
    dimensions = [sbx.info['length'], sbx.info['sz'][0], sbx.info['sz'][1]]
    plane_dimensions = list(sbx.shape)
    if not sbx.info['scanmode']: # bidirectional
        margin = 100
        dimensions[2] = dimensions[2] - 100
        plane_dimensions[2] = plane_dimensions[2] - 100
    dimensions = tuple(dimensions)
    plane_dimensions = tuple(plane_dimensions)

    # TODO: Allow options for aligning red channel and/or using it to align green.
    # if multichannel, align green channel
    input_data_set = sbx.data()[channel]
    if len(sbx.channels) > 1:
        channel = '_' + channel
    else:
        channel = ''

    # if none is provided, create file to save translations
    if isinstance(translations, type(None)):
        translations_filename = 'moco_aligned_{}{}_translations'.format(sbx.filename, channel)
        translations_file = tempfile.NamedTemporaryFile(delete=True)
        temp_filename = translations_file.name
        savetrans = True
        tmode = 'w+'
        fill = True
    else:
        temp_filename = translations
        savetrans = False
        tmode = 'r+'
        fill = False
    translations_set = np.memmap(temp_filename,
                                 dtype='|S21',
                                 shape=(dimensions[0], 3),
                                 mode=tmode)
    translations_set = {'plane_{}'.format(i): translations_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    if fill == True:
        for plane in translations_set.values():
            plane[:,0] = 'empty'

    # TODO: Allow option to select template by plane.
    # check if template is user-selected
    if templates == None: # templates were not provided, generate them
        if template_indices == None:
            templates = [plane[20:40,:,margin:].mean(0) for plane in input_data_set.values()]
        else:
            template_indices = slice(template_indices)
            templates = [plane[template_indices,:,margin:].mean(0) for plane in input_data_set.values()]
        templates = map(np.uint16, templates) # convert tempaltes to uint16

    # choose whether to split planes
    if split == False or sbx.num_planes == 1:
        filename = 'moco_aligned_{}{}.sbx'.format(sbx.filename, channel)
        mode = 'r+' if os.path.exists(filename) else 'w+'
        output_data_set = np.memmap(filename,
                                    dtype='uint16',
                                    shape=(dimensions),
                                    mode=mode)
        output_data_set = {'plane_{}'.format(i): output_data_set[i::sbx.num_planes] for i in range(sbx.num_planes)}
    elif split == True:
        output_data_set = {}
        for plane in range(sbx.num_planes):
            filename = 'moco_aligned_{}{}_plane_{}.sbx'.format(sbx.filename, channel, plane)
            mode = 'r+' if os.path.exists(filename) else 'w+'
            output_data_set.update({'plane_{}'.format(plane):np.memmap(filename,
                                                                       dtype='uint16',
                                                                       shape=(plane_dimensions),
                                                                       mode=mode)
                                                                       })

    # if true save metadata files
    if savemat == True:
        spio_info = lmat.loadmat(sbx.filename + '.mat')
        for plane, output_data in output_data_set.items():
            spio_info['info']['sz'] = output_data.shape[1:]
            spio_info['info']['channels'] = 2 # TODO: may need to update when including red channel
            if split == True:
                spio_info['info']['resfreq'] = spio_info['info']['resfreq'] / sbx.num_planes
                spio_info['info']['otparam'] = []
            spio.savemat(os.path.splitext(output_data.filename)[0] + '.mat', {'info':spio_info['info']})

    # prepare template parameters for each plane
    template_params_set = {}
    for i, template in enumerate(templates):
        ds_template = cv2.pyrDown(template)
        rows, cols = ds_template.shape
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
        input_data = input_data_set[plane]
        output_data = output_data_set[plane]
        plane_translations = translations_set[plane]
        indices = validate_range(np.array(indices), input_data.shape[0])
        if savemat == True:
            p = plane.split('_')[-1]
            print('Aligning plane {}/{}'.format(int(p)+1, sbx.num_planes))
        for idx in indices:
            moving = input_data[idx,:,margin:]
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
            xy = 2 * xy


            rows, cols = moving.shape
            cx = rows / 250
            cx = 1 if not cx else cx # in case height is too short
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

            newX, newY = find_z(cx,cy,cart,f_moving,f_template,Lx,Rx,Ly,Ry,xy,xy2,rows,cols)
            plane_translations[idx] = ['applied', newX, newY]
            M = np.float32([[1,0,newX],[0,1,newY]])
            output_data[idx] = np.uint16(cv2.warpAffine(np.float32(moving),M,(cols,rows)))

    if savetrans == True:
        np.save(translations_filename, translations_set)
        translations_file.close()
