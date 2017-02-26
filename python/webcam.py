import cv2
import numpy as np
import struct

class camera(object):
    def __init__(self,deviceID=0):
        self.deviceID = deviceID
        self.cap = cv2.VideoCapture(self.deviceID)
        self.recording = np.uint8(np.array([]))
        self.times = np.array([])
        self.frameCount = 0
        self.capResolution = [self.cap.get(3),self.cap.get(4)]
        
    def grabFrame(self,timestamp):
        ret, frame = self.cap.read()
        gray_frame = cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)
        ds_frame = cv2.pyrDown(gray_frame)
        self.recording = np.append(self.recording,ds_frame)
        self.times = np.append(self.times,timestamp)
        self.frameCount += 1
        self.width = ds_frame.shape[1]
        self.height = ds_frame.shape[0]
        
    def saveRec(self,fname):
        '''
        Saves recording to file, 'fname', as binary data.
        First 12 bytes reserved for data shape info.
        '''
        f = open(fname,'w')
        f.write(struct.pack('iii',self.frameCount,self.height,self.width))
        f.close()
        f = open(fname,'a')
        self.recording.tofile(f)
        f.close()
    
    def release(self):
        ''' 
        Releases associated camera.
        '''
        self.cap.release()
    
def loadRecording(fname):
    '''
    Reads camera recording as numpy memmapped object and outputs the shaped data
    '''
    f = open(fname,'r')
    shape = struct.unpack('iii',f.read(12))
    data = np.memmap(f,dtype='uint8',mode='r',offset=12,shape=shape)
    return data