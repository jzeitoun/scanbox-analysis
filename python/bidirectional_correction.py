import numpy as np
import cv2

def shift_lines(frame,x):
    _frame = frame.copy()
    odd_lines = _frame[1::2,:]
    M = np.float32([[1,0,x],[0,1,0]])
    _frame[1::2,:] = np.uint16(cv2.warpAffine(np.float32(odd_lines),M,(odd_lines.shape[1],odd_lines.shape[0])))
    return _frame