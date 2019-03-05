import numpy as np

from sbxmap import sbxmap
from moco_v2 import apply_plane_translations
from statusbar import Statusbar

import os
import sys

def prompt():
    answer = raw_input("Continue? (Y/N): ")
    answer = answer.capitalize()
    if answer == 'N':
        sys.exit()
    elif answer == 'Y':
        return
    else:
        print('Not a valid response.')
        prompt()

def main():
    '''
    Usage: <source_file> <sink_file> <plane_to_align> <align_plane>
    '''
    source_file = sys.argv[1]
    sink_file = sys.argv[2]

    assert 'moco' not in source_file
    assert 'moco_aligned' in sink_file

    plane_to_align = sys.argv[3]
    align_plane = sys.argv[4]
    base_name = os.path.splitext(sink_file)[0]
    translations = np.load(
            '_'.join(base_name.split('_')[:5]) + '_translations.npy'
            ).tolist()

    channels = sbxmap(sink_file).channels

    print(

'''
Applying translations
---------------------
Input file: {}
Ouput file: {}
Align plane: {}
Translations plane: {}
'''.format(source_file, sink_file, plane_to_align, align_plane)

    )

    prompt()

    for channel in channels:
        print('\nApplying translations to {} channel'.format(channel))
        status = Statusbar(sbxmap(sink_file).shape[0], 50)
        status.initialize()
        for idx in apply_plane_translations(source_file, sink_file, channel,
            plane_to_align, align_plane, translations):
            status.update(idx)

if __name__ == '__main__':
    main()
