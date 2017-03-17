import numpy as np
import scipy.io as sio
import os

from pacu.core.io.scanbox.impl2 import ScanboxIO
from pacu.core.io.scanbox.view.trial_merged_roi import TrialMergedROIViewByCentroid

class stitched_data(object):
    '''
    Create this object in directory that contains the .io files of interest.
    fw_array should be list of tuples with the filename first and the workspace name second.
    Example: ('Day1_000_000','Workspace_1'),('Day1_000_001',Workspace_1')
    '''
    def __init__(self,fw_array):
	self.path = os.getcwd()
        self.io = [ScanboxIO(os.path.join(self.path,fw[0])) for fw in fw_array]
        self.workspaces = [workspace for data,fw in zip(self.io, fw_array) for workspace in data.condition.workspaces if workspace.name == fw[1]]
        self.rois = [workspace.rois for data, fw in zip(self.io, fw_array) for workspace in data.condition.workspaces if workspace.name == fw[1]]
        self.merged_rois = [TrialMergedROIViewByCentroid(roi.centroid,*self.workspaces) for roi in self.rois[0]] 
        self.refresh_all()
	self.roi_dict = self.make_roi_dict()
	 
    def refresh_all(self):
        for merged_roi in self.merged_rois:
	    merged_roi.refresh()

    def make_roi_dict(self):
        merged_rois_dict = {'{}{}'.format('id_',merged_roi.rois[0].id):merged_roi.serialize() for merged_roi in self.merged_rois}
        #for merged_roi in self.merged_rois:
	    #merged_rois_dict[str(merged_roi.rois[0].id)] = merged_roi.serialize() # for now, using the id of the first ROI as the merged id
            #merged_roi_ref = merged_rois_dict[idx]
            #merged_roi_ref
	    #merged_roi_ref['centroid'] = merged_roi.centroid
	    #merged_roi_ref['df/f'] = [dict(dff0.attributes.items()[5:]) for dff0 in merged_roi.dff0s] 
            ##merged_roi_ref['df/f'] = [dff0.toDict() for dff0 in merged_roi.dff0s]
	    ##merged_roi['anova_each'] = [anovaeach.attributes.items()[5:-1] for anovaeach in merged_roi.anovaeachs]
	    ##merged_roi_ref['anova_each'] = [dtanovaeach.toDict() for dtanovaeach in merged_roi.dtanovaeachs]
	    #merged_roi_ref['anova_each'] = [[dtanovaeach.attributes.items()[i] for i in [8,10,16,17]] for dtanovaeach in merged_roi.dtanovaeachs]  
            #merged_roi_ref['orientation_best_prefs'] = dict([merged_roi.dtorientationbestprefs[0].attributes.items()[i] for i  in [10,16]])
            ##merged_roi_ref['orientation_best_prefs'] = [dtorientationbestpref.toDict() for dtorientationbestpref in merged_roi.dtorientationbestprefs]
	    ##merged_roi_ref['orientations_fits'] = [dtorientationsfit.toDict() for dtorientationsfit in merged_roi.dtorientationsfits]
	    #merged_roi_ref['orientations_fits'] = [dict([dtorientationsfit.attributes.items()[i] for i in [8,10,16]]) for dtorientationsfit in merged_roi.dtorientationsfits]
	    ##merged_roi_ref['orientations_means'] = [dtorientationsmean.toDict() for dtorientationsmean in merged_roi.dtorientationsmeans]
	    #merged_roi_ref['orientations_means'] = [dict([dtorientationsmean.attributes.items()[i] for i in [8,10,16,17,18,19,20]]) for dtorientationsmean in merged_roi.dtorientationsmeans]
	    ##merged_roi_ref['s.freq_fits'] = [dtsfreqfit.toDict() for dtsfreqfit in merged_roi.dtsfreqfits]
        return merged_rois_dict

    def export_mat(self):
        merged_dict = {}
	merged_dict['filenames'] = [fw[0][:-3] for fw in fw_array]
	merged_dict['workspaces'] = [workspace.name for workspace in self.workspaces]
	merged_dict['rois'] = self.roi_dict 
        sio.savemat(fw_array[0][0][:-3] + '_merged.mat',{'merged_dict':merged_dict})             

