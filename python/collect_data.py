import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import os

eye1_scale = 138.0/4
eye2_scale = 195.0/4

class roi():
    def __init__(self,data):
        self.df = pd.read_pickle(data)

    def slope_gain_eye1(self):
        df = self.df.copy()
        raw_vals = np.float64(df[['Eye 1 Mean Pupil Area','Pref r-value','trial_sf']].as_matrix())
        raw_vals = raw_vals[~np.isnan(raw_vals).any(axis=1)]                                      
        # convert to diameter                                                                     
        #raw_vals[:,0] = (2*np.sqrt(raw_vals[:,0]/np.pi))/eye1_scale                               
        raw_vals_df = pd.DataFrame(raw_vals,columns=['x','y','sf'])
        model = pd.ols(x=raw_vals_df['x'],y=raw_vals_df['y'])
        peak_sf = round(np.mean(raw_vals_df['sf']),2)
        r_value = np.sqrt(model.r2)
        return model.beta.x, peak_sf, r_value

    def gain_eye1(self,cutoff):
        df = self.df.copy()
        raw_vals = np.float64(df[['Eye 1 Mean Pupil Area','Pref r-value','trial_sf']].as_matrix())
        raw_vals = raw_vals[~np.isnan(raw_vals).any(axis=1)]
        # convert to diameter
        raw_vals[:,0] = (2*np.sqrt(raw_vals[:,0]/np.pi))/eye1_scale
        high = raw_vals[raw_vals[:,0] >= cutoff]
        low = raw_vals[raw_vals[:,0] < cutoff]
        relative_gain = np.mean(high[:,1])/np.mean(low[:,1])
        peak_sf = round(np.mean(raw_vals[:,2]),2)
        return relative_gain,peak_sf

    def slope_gain_eye2(self):                                                                    
        df = self.df.copy()                                                                       
        raw_vals = np.float64(df[['Eye 2 Mean Pupil Area','Pref r-value','trial_sf']].as_matrix())
        raw_vals = raw_vals[~np.isnan(raw_vals).any(axis=1)]                                      
        # convert to diameter                                                                     
        raw_vals[:,0] = (2*np.sqrt(raw_vals[:,0]/np.pi))/eye2_scale                               
        raw_vals_df = pd.DataFrame(raw_vals,columns=['x','y','sf'])                               
        model = pd.ols(x=raw_vals_df['x'],y=raw_vals_df['y'])                                     
        peak_sf = round(np.mean(raw_vals_df['sf']),2)                                             
        return model.beta.x,peak_sf                                                               
                                                                                              
    def gain_eye2(self,cutoff):                                                                   
        df = self.df.copy()                                                                       
        raw_vals = np.float64(df[['Eye 2 Mean Pupil Area','Pref r-value','trial_sf']].as_matrix())
        raw_vals = raw_vals[~np.isnan(raw_vals).any(axis=1)]                                      
        # convert to diameter                                                                     
        raw_vals[:,0] = (2*np.sqrt(raw_vals[:,0]/np.pi))/eye2_scale                               
        high = raw_vals[raw_vals[:,0] >= cutoff]                                                  
        low = raw_vals[raw_vals[:,0] < cutoff]                                                    
        relative_gain = np.mean(high[:,1])/np.mean(low[:,1])                                      
        peak_sf = round(np.mean(raw_vals[:,2]),2)                                                 
        return relative_gain,peak_sf                                                               

def collect_rois():
    dir_list = os.listdir(os.getcwd())
    data = [roi(os.path.join(directory,f)) for directory in dir_list if os.path.isdir(directory) for f in os.listdir(os.path.abspath(directory)) if '_analysis' in f]
    return data

def combine_peak_responses(data,eye,p_val):
    combined_data = np.concatenate([d.df[[eye + ' Mean Pupil Area','Pref r-value']].as_matrix() for d in data if d.df['Pref Anova Each P'][0] <= p_val])
    combined_data = np.float64(combined_data)
    combined_data = combined_data[~np.isnan(combined_data).any(axis=1)]
    combined_data = pd.DataFrame(combined_data,columns=['x','y'])
    return combined_data

def plot_scatter(combined_data):
    model = pd.ols(x=combined_data['x'],y=combined_data['y'])
    plt.scatter(x=combined_data['x'],y=combined_data['y'])
    plt.plot(combined_data['x'],model.beta.x*combined_data['x']+model.beta.intercept,'r-')
    xlabel('Pupil Area (Pixels)')
    ylabel('Pref R-Value')
    ax = gca()
    max_x = ax.properties()['xlim'][1]
    max_y = ax.properties()['ylim'][1]
    ax.text(0.6*max_x, 0.25*max_y, '{}{:f}{}{}{:f}'.format('$r^2$ = ',model.r2,', ','p = ',model.p_value.x))
    return model

def plot_scatter_diam(_combined_data,scale): 
    combined_data = _combined_data.copy()
    combined_data['x'] = (2*np.sqrt(combined_data['x']/np.pi))/scale
    model = pd.ols(x=combined_data['x'],y=combined_data['y'])                                                                                                                    
    plt.scatter(x=combined_data['x'],y=combined_data['y'])                                                                                                                       
    plt.plot(combined_data['x'],model.beta.x*combined_data['x']+model.beta.intercept,'r-')                                                                                       
    xlabel('Pupil Diameter (mm)')                                                                                                                                                
    ylabel('Pref R-Value')                                                                                                                                                       
    ax = gca()
    max_x = ax.properties()['xlim'][1]                                                                                                                                           
    max_y = ax.properties()['ylim'][1]                                                                                                                                           
    ax.text(0.6*max_x, 0.25*max_y, '{}{:f}{}{}{:f}'.format('$r^2$ = ',model.r2,', ','p = ',model.p_value.x))       
    return model     

