import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

def findSmoothVelocity(csvFile,tolerance_val='30'):
    ''' 
    Accepts .csv data.
    Calculates the velocity (dx/dt) of the position vector.
    Position data is matched to frame timestamps within +/- specified tolerance (default = 30ms) and forward fills any NaN values. 
    The resulting timeseries contains one position data point for every frame timestamp.
    Velocity is then calculated from this dataset.
    '''
    # read csv data
    data = pd.read_csv(csvFile,names=('123456'))
    # extract position and TTL count data into separate data frames
    fData = data[data['2'].str.contains('count-21')==True][['1','3']] 
    pData = data[data['2'].str.contains('position')==True][['1','4']]
    # create timestamped dataframes
    frameData = pd.DataFrame({'Time': pd.to_datetime(fData['1'],unit='s'),'Count': fData['3']},columns=['Time','Count'])
    positionData = pd.DataFrame({'Time': pd.to_datetime(pData['1'],unit='s'),'Y-Position': pData['4']},columns=['Time','Y-Position'])
    # merge data
    dataSet = pd.merge_asof(frameData,positionData,on='Time',tolerance=pd.Timedelta(tolerance_val))
    # forward fill Y-position NaN values
    dataSet = dataSet.ffill()
    # calculate velocity and add to dataSet
    dataSet['Velocity'] = dataSet['Y-Position'].diff()/(dataSet['Time'].diff()/np.timedelta64(1,'s'))
    # normalize time & set NaN to zero
    dataSet['Time'] = dataSet['Time']-dataSet['Time'][0]
    dataSet = dataSet.fillna(0)
    return dataSet
    
    
def plotVelocity(dataSet):
    '''
    Plots velocity vector from dataSet
    '''
    plt.figure()
    float_velocity = np.array(dataSet['Velocity'])
    float_time = np.array(dataSet['Time']/np.timedelta64(1,'s'))
    plt.xlim(float_time[0],float_time[-1])
    plt.xlabel('Time (Seconds)')
    plt.ylabel('Velocity (cm/s)')
    plt.grid(True)
    plt.plot(float_time,float_velocity,label = 'Velocity Data')
    plt.legend(loc='upper left')
        
    
