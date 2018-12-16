import numpy as np
import h5py

import datetime
import sys

from sbxmap import sbxmap

TIME_NOW = datetime.datetime.now()
try:
    frate_idx = sys.argv.index('--frate')
    framerate = sys.argv[frate_idx + 1]
    INCREMENT = 1/int(framerate)
    UNIT = 'seconds'
except:
    raise ValueError('Framerate needs to be specified in Hz. (Example: --frate 8).')

################################################################################
#                             User-Defined Functions                           #
################################################################################

def get_histogram(frame):
    if frame.dtype == np.uint16:
        frame_8bit = (frame/65535*255).astype('uint8')
    hist, _ = np.histogram(frame_8bit.ravel(), bins=256)

    return np.uint64(hist)

def get_channel_color(channel):
    lookup = {
            0: '0.000 1.000 0.000',
            1: '1.000 0.000 0.000'
            }

    return lookup[channel]

def generate_time(data):
    num_timepoints = len(data)
    id = np.arange(num_timepoints)
    birth = np.arange(0, num_timepoints) * 10**9
    death = np.arange(1, num_timepoints+1) * 10**9
    time_begin = np.zeros(num_timepoints)

    return np.array(
        list(zip(id, birth, death, time_begin)),
        dtype=[('ID', '<i8'), ('Birth', '<i8'),
            ('Death', '<i8'), ('IDTimeBegin', '<i8')]
        )

def generate_time_info(data, increment, unit):
    num_timepoints = len(data)

    def increment_time(time, delta, unit='millis'):
        format_lookup = {
                'days': 0,
                'seconds': 1,
                'micros': 2,
                'millis': 3,
                'minutes': 4,
                'hours': 4,
                }
        format = format_lookup[unit]
        new_time = time + datetime.timedelta(
                *((0,)*format + (delta,)) # example format: (0, 0, 0, 1)
                )
        return new_time.isoformat(' ')[:-3]

    timepoints = {
            'TimePoint{}'.format(i) :
            increment_time(TIME_NOW, i*increment, unit) for i in range(num_timepoints)
            }

    return timepoints


################################################################################
#                              Spec Definition                                 #
################################################################################

SPEC = {
            'per_frame':
            [
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSet/ResolutionLevel 0/TimePoint {}/Channel {}',
                        'values': ['t', 'c']
                        },
                    'attributes': {
                        'ImageSizeX': {
                            'func': np.size,
                            'kwargs': {'axis': 2}
                            },
                        'ImageSizeY': {
                            'func': np.size,
                            'kwargs': {'axis': 1}
                            },
                        'ImageSizeZ': {
                            'func': np.size,
                            'kwargs': {'axis': 0}
                            },
                        'HistogramMin': {
                            'func': np.min
                            },
                        'HistogramMax': {
                            'func': np.max
                            }
                        }
                    },
                {
                    'type': 'dataset',
                    'path': {
                        'text': 'DataSet/ResolutionLevel 0/TimePoint {}/Channel {}/Data',
                        'values': ['t', 'c']
                        },
                    'attributes': None,
                    'value': {
                        'kwargs': {'compression': 'gzip', 'chunks': True}
                        }
                    },
                {
                    'type': 'dataset',
                    'path': {
                        'text': 'DataSet/ResolutionLevel 0/TimePoint {}/Channel {}/Histogram',
                        'values': ['t', 'c']
                        },
                    'attributes': None,
                    'value': {
                        'func': get_histogram,
                        }
                    }
                ],
            'per_channel':
            [
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/Channel {}',
                        'values': ['c']
                        },
                    'attributes': {
                        'Color': {
                            'func': get_channel_color
                            },
                        'ColorMode': 'BaseColor',
                        'ColorOpacity': '1.000',
                        'ColorRange': '0.000 65535.000',
                        'Description': '(description not specified)',
                        'GammaCorrection': '1.000',
                        'Name': '(name not specified)'
                        }
                    }
                ],
            'per_file':
            [
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/Imaris'
                        },
                    'attributes': {
                        'ImageId': '100001',
                        'ThumbnailMode': 'thumbnailMIP',
                        'ThumbnailSize': '256',
                        'Version': '9.1'
                        }
                    },
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/ImarisDataSet'
                        },
                    'attributes': {
                        'Creator': 'SBX Converter',
                        'NumberOfImages': '1',
                        'Version': '9.1'
                        }
                    },
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/Log'
                        },
                    'attributes': {
                        'Entries': '0',
                        }
                    },
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/Image'
                        },
                    'attributes': {
                        'ExtMin0': '0',
                        'ExtMin1': '0',
                        'ExtMin2': '0',
                        'ExtMax0': {
                            'func': np.size,
                            'kwargs': {'axis': 4}
                            },
                        'ExtMax1': {
                            'func': np.size,
                            'kwargs': {'axis': 3}
                            },
                        'ExtMax2': {
                            'func': np.size,
                            'kwargs': {'axis': 2}
                            },
                        'RecordingDate': TIME_NOW.isoformat(' ')[:-3],
                        'Description': '(description not specified)',
                        'Name': '(name not specified)',
                        'ResampleDimensionY': 'true',
                        'ResampleDimensionX': 'true',
                        'ResampleDimensionZ': 'true',
                        'Y': {
                            'func': np.size,
                            'kwargs': {'axis': 3}
                            },
                        'X': {
                            'func': np.size,
                            'kwargs': {'axis': 4}
                            },
                        'Z': {
                            'func': np.size,
                            'kwargs': {'axis': 2}
                            },
                        'Unit': 'um',
                        'OriginalFormat': 'SBX'
                        }
                    },
                {
                    'type': 'group',
                    'path': {
                        'text': 'DataSetInfo/TimeInfo',
                        },
                    'attributes': {
                        'DataSetTimePoints': {
                            'func': np.size,
                            'kwargs': {'axis': 0}
                            },
                        'FileTimePoints': {
                            'func': np.size,
                            'kwargs': {'axis': 0}
                            },
                        'ADD': {
                            'func': generate_time_info,
                            'kwargs': {'increment': INCREMENT, 'unit': UNIT}
                            }
                        }
                    },
                {
                    'type': 'dataset',
                    'path': {
                        'text': 'DataSetTimes/TimeBegin'
                        },
                    'attributes': None,
                    'value': {
                        'data': np.array(
                            (0, bytes(TIME_NOW.isoformat(' ')[:-3], 'utf-8')),
                            dtype=[('ID', '<i8'), ('ObjectTimeBegin', 'S256')]
                            )
                        }
                    },
                {
                    'type': 'dataset',
                    'path': {
                        'text': 'DataSetTimes/Time'
                        },
                    'attributes': None,
                    'value': {
                        'func': generate_time
                        }
                    }
                ],
                'root_attrs': {
                        'DataSetDirectoryName': 'DataSet',
                        'DataSetInfoDirectoryName': 'DataSetInfo',
                        'ImarisDataSet': 'ImarisDataSet',
                        'ImarisVersion': '5.5.0',
                        'NumberOfDataSets': np.array((1,), dtype=np.uint32),
                        'ThumbnailDirectoryName': 'Thumbnail'
                        }
                }
