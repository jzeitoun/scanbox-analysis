import numpy as np
import scipy.io as sio
import os

from pacu.core.io.scanbox.impl2 import ScanboxIO
from pacu.core.io.scanbox.view.trial_merged_roi import TrialMergedROIViewByCentroid

class stitched_data(object):
    '''
    Create this object in directory that contains the .io files of interest.
    Argument should be list of tuples with the filename first and the workspace name second.
    Example: stitched_dataset = stitched_data(['Day1_000_000','Workspace_1'),('Day1_000_001',Workspace_1')])
    '''
    def __init__(self,fw_array):
	self.path = os.getcwd()
        self.io = [ScanboxIO(os.path.join(self.path,fw[0])) for fw in fw_array]
        self.workspaces = [workspace for data,fw in zip(self.io, fw_array) for workspace in data.condition.workspaces if workspace.name == fw[1]]
        self.rois = [workspace.rois for data, fw in zip(self.io, fw_array) for workspace in data.condition.workspaces if workspace.name == fw[1]]
        self.merged_rois = [TrialMergedROIViewByCentroid(roi.centroid,*self.workspaces) for roi in self.rois[0]] 
        self.refresh_all()
	self.roi_dict = {'{}{}'.format('id_',merged_roi.rois[0].id):merged_roi.serialize() for merged_roi in self.merged_rois}
	 
    def refresh_all(self):
        for merged_roi in self.merged_rois:
	    merged_roi.refresh()

    def export_mat(self):
        merged_dict = {}
	merged_dict['filenames'] = [fw[0][:-3] for fw in fw_array]
	merged_dict['workspaces'] = [workspace.name for workspace in self.workspaces]
	merged_dict['rois'] = self.roi_dict 
        sio.savemat(fw_array[0][0][:-3] + '_merged.mat',{'merged_dict':merged_dict})             

