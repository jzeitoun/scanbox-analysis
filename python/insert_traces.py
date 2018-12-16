import numpy as np
import json

import sys
import os

from pacu.core.io.scanbox.impl2 import ScanboxIO
from pacu.core.io.scanbox.method.trial.dff0 import get_trial_indices

'''
File must have only one workspace for this script to work.

JSON must be in format:
    [
      {
        roi_id: <id>,
        trace: <array>
      }
    ]
'''

def load_rois(rois_filename):
    with open(rois_filename, 'r') as f:
        rois = json.load(f)
    return rois

def connect_db(io_filename):
    path = os.path.abspath(io_filename)
    io = ScanboxIO(path)
    return io

def insert_traces(io, rois):
    '''
    Updates each of the trial "dttrialdff0s" objects with the corresponding segment
    of the custom trace.
    '''
    workspace = io.condition.workspaces.first
    condition = io.condition
    roi_id_map = {roi.id: roi for roi in io.condition.workspaces.first.rois}
    for roi in rois:
        if 'trace' not in roi:
            continue
        trace = np.array(roi['trace'])
        db_roi = roi_id_map[roi['roi_id']]
        for trial in db_roi.dttrialdff0s:
            indices = get_trial_indices(workspace, condition, trial)
            trial.value['baseline'] = trace[slice(*indices['baseline'])]
            trial.value['on'] = trace[slice(*indices['on'])]
    io.db_session.flush() # Commit updates

def main():
    rois = load_rois(sys.argv[1])
    io = connect_db(sys.argv[2])

    print('Inserting traces...')
    insert_traces(io, rois)

    print('Done.')

if __name__ == '__main__':
    main()
