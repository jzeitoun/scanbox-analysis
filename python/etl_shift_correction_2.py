#!/usr/bin/python

# etl_shift_correction_2.py
# align optotune files
# Dhruba Banerjee
# 2/5/19

# Jack Zeitoun
# Cleaned up and made compatible with LizardFS
# 1/15/19

import numpy as np
from scipy import stats, signal
from matplotlib import pyplot
import cv2

import sys
import os
import shutil
import time
import tempfile

from pathlib import Path
import argparse

from sbxmap import sbxmap
from statusbar import Statusbar


def copyfileobj(fsrcname, fdstname, callback, length=16*1024):
    with open(fsrcname) as fsrc, open(fdstname, 'w+') as fdst:
        fsize = os.path.getsize(fsrcname)
        copied = 0
        while True:
            buf = fsrc.buffer.read(length)
            if not buf:
                break
            fdst.buffer.write(buf)
            copied += len(buf)
            percent = copied/fsize*100
            callback(percent)

def displayProgressPercent(val):
    sys.stdout.write('\r')
    sys.stdout.write('Copying File: {:.2f}%'.format(val))
    sys.stdout.flush()

def automatic_shift(unaligned_file, read_file, save_file, directory=os.getcwd(), avg_over=100):
    """Corrects for offsets between planes in optotune recordings."""

    unaligned_file = Path(unaligned_file)
    read_file = Path(read_file)
    save_file = Path(save_file)

    shutil.copy(read_file.with_suffix('.sbx'), save_file.with_suffix('.sbx'))
    shutil.copy(read_file.with_suffix('.mat'), save_file.with_suffix('.mat'))

    w_sbx = sbxmap(save_file.with_suffix('.sbx'))
    sbx = sbxmap(unaligned_file.with_suffix('.sbx'))

    nplanes = sbx.num_planes
    nchan= len(sbx.channels)
    c = 15
    t = 20
    corr_shift = []

    progress_max = nplanes + (nplanes*sbx.shape[0])
    status = Statusbar(progress_max, barsize=50)
    status.initialize()

    for x in range(nplanes):
        if nchan==1:
            im = np.average(~sbx.data()['green']['plane_{0}'.format(x)][1:avg_over,:,:],0)
        elif nchan>1:
            im = np.average(~sbx.data()['red']['plane_{0}'.format(x)][1:avg_over,:,:],0)

        im_trimmed = im[20:-20, 20:-20]
        im_norm = 255 * im_trimmed.astype(np.float64) / np.max(im_trimmed)
        r, im_thresh = cv2.threshold(im_norm.astype(np.uint8), t, 255, cv2.THRESH_BINARY_INV)
        # im_adthresh = cv2.adaptiveThreshold(im_norm.astype(np.uint8),255,cv2.ADAPTIVE_THRESH_MEAN_C,cv2.THRESH_BINARY,c,10)

        if x>0:
            corr = signal.fftconvolve(prev_thresh,im_thresh[::-1,::-1],mode='same')
            corr_shift.append(np.unravel_index(np.argmax(corr),corr.shape))

        prev_thresh = im_thresh

        # # plot the raw, threshold, and adaptive thresholded images
        # ax[x,0].imshow(im,'gray',aspect="equal")
        # ax[x,1].imshow(im_thresh,'gray',aspect="equal")
        # ax[x,2].imshow(im_adthresh,'gray',aspect="equal")
        # ax[x,0].set(ylabel='{0}'.format(x))

        # # find contours
        # contours, heirarchy = cv2.findContours(im_thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
        # for c in contours:
        #   M = cv2.moments(c)
        #   if M["m00"] != 0 and cv2.contourArea(c)>25:
        #       cX = int(M["m10"]/M["m00"])
        #       cY = int(M["m01"]/M["m00"])
        #       ax[x,1].scatter(cX,cY,s=1,alpha=0.5)

        status.update(x)

    # ipdb.set_trace()

    corr_array = np.array(corr_shift)
    shifts = np.asmatrix(corr_array - [im_thresh.shape[0]/2, im_thresh.shape[1]/2])

    # x_shift = stats.mode(shifts[:,0])[0][0]
    # y_shift = stats.mode(shifts[:,1])[0][0]

    early = -np.cumsum(shifts[range(int(nplanes/2))[::-1]], axis=0)[::-1]
    late = np.cumsum(shifts[nplanes//2:nplanes:1], axis=0)

    concat_shifts = np.concatenate((early, [[0,0]], late))

    sbx_groupavg = sbxmap(read_file.with_suffix('.sbx'))
    rows, cols = im.shape

    for i in range(nplanes):
        if nchan>1:
            im_red = sbx_groupavg.data()['red']['plane_{0}'.format(i)]
        im_green = sbx_groupavg.data()['green']['plane_{0}'.format(i)]
        #ax[i,0].imshow(np.mean(im_red[1:10,:,:],0),'gray')

        M = np.float32([[1, 0, concat_shifts[i, 1]], [0, 1, concat_shifts[i, 0]]])
        if nchan>1:
            im_red_shifted = np.zeros(im_red.shape)
        im_green_shifted = np.zeros(im_green.shape)

        for j in range(im_green.shape[0]):
            if nchan>1:
                im_red_shifted[j,:,:] = cv2.warpAffine(im_red[j,:,:], M, (cols, rows))
            im_green_shifted[j,:,:] = cv2.warpAffine(im_green[j,:,:], M, (cols, rows))

            status.update(nplanes + (i * sbx.shape[0]) + j)

        if nchan>1:
            w_sbx.data()['red']['plane_{0}'.format(i)][:] = im_red_shifted
        w_sbx.data()['green']['plane_{0}'.format(i)][:] = im_green_shifted

    status.update(progress_max)


def plot_shift(original_sbx, shifted_sbx, panels):

    sbx = sbxmap(original_sbx)
    sbx_shifted = sbxmap(shifted_sbx)

    for i in range(20):
        if i%panels == 0:
            f,ax = pyplot.subplots(panels,2,sharex=True,sharey=True)
            f.subplots_adjust(hspace=.1,wspace=.01)
            ax[0,1].set(title='Original Image')
            ax[0,0].set(title='Shifted Image')

        ax[i%panels,0].imshow(np.mean(~sbx.data()['red']['plane_{0}'.format(i)],0),'gray')
        ax[i%panels,1].imshow(np.mean(~sbx_shifted.data()['red']['plane_{0}'.format(i)],0),'gray')


def main():
    parser = argparse.ArgumentParser(description='Align optotune recordings.')
    parser.add_argument('unaligned_file', help='This is the file to align.')
    parser.add_argument('-s', '--save', help='Choose output file name.', dest='save_file')
    parser.add_argument('-r', '--read', help='File to pull registration transforms from.', dest='read_file')

    args = parser.parse_args()

    unaligned_file = Path(args.unaligned_file).with_suffix('.sbx')

    if args.save_file:
        if args.save_file == args.unaligned_file:
            raise ValueError('"Save file" cannot be the same as the "Unaligned file".')
        else:
            save_file = Path(args.save_file)
    else:
        save_file = Path(os.path.splitext(args.unaligned_file)[0] + '_etl_corrected').with_suffix('.sbx')

    if args.read_file:
        read_file = Path(args.read_file).with_suffix('.sbx')
    else:
        read_file = unaligned_file

    tmpdir_path = Path(tempfile.mkdtemp(dir='/mnt/swap'))
    tmp_unaligned_file = tmpdir_path.joinpath(unaligned_file)
    tmp_read_file = tmpdir_path.joinpath(read_file)
    tmp_save_file = tmpdir_path.joinpath(save_file)

    shutil.copy(unaligned_file.with_suffix('.mat'), tmpdir_path)
    copyfileobj(unaligned_file.as_posix(), tmp_unaligned_file.as_posix(), displayProgressPercent)

    # If using a "read_file" for alignment, copy to temp direcory
    if read_file != unaligned_file:
        print('\n')
        shutil.copy(read_file.with_suffix('.mat'), tmpdir_path)
        copyfileobj(read_file.as_posix(), tmp_read_file.as_posix(), displayProgressPercent)

    basepath = unaligned_file.absolute().parent
    os.chdir(tmpdir_path)

    print('\nAligning...')
    start = time.time()
    automatic_shift(tmp_unaligned_file.as_posix(), tmp_read_file.as_posix(), tmp_save_file.as_posix())
    print('\nFinished in {:.2f} seconds.'.format(time.time() - start))

    os.chdir(basepath)
    try:
        shutil.copy(tmp_save_file.with_suffix('.mat'), basepath)
        copyfileobj(tmp_save_file.as_posix(), save_file.as_posix(), displayProgressPercent)
    except OSError:
        print(f'\nError copying files. Aligned files saved in {tmpdir_path}')
        return
    shutil.rmtree(tmpdir_path)


if __name__ == '__main__':
    main()

