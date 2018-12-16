import numpy as np
import h5py

from datetime import datetime

from statusbar import Statusbar

from sbxmap import sbxmap


# This is important for Imaris compatibility
tid = h5py.h5t.C_S1.copy()
tid.set_size(1)
H5T_C_S1_64 = h5py.Datatype(tid)

################################################################################
#                               Core Functions                                 #
################################################################################

def construct(fh, data, spec):
    """ Data structure must be in TCZYX format. """

    per_frame_spec = spec['per_frame']
    per_channel_spec = spec['per_channel']
    per_file_spec = spec['per_file']
    root_attributes = spec['root_attrs']

    num_timepoints, num_channels, _, _, _ = data.shape
    num_tasks = num_timepoints * num_channels

    per_frame_status = Statusbar(num_tasks, title='Processing frames...',
            mem_monitor=True)
    per_frame_status.initialize()

    # First iterate through frames.
    for t, timepoint in enumerate(data):
        for c, frame in enumerate(timepoint):

            axes_lookup = {
                    't': t,
                    'c': c,
                    }

            apply_spec(fh, frame, per_frame_spec, axes_lookup)
            per_frame_status.update(t*num_channels+c+1)

    # Next, iterate through number of channels.
    num_channels = data.shape[1]
    for c in range(num_channels):

        axes_lookup = {
                'c': c,
                }

        apply_spec(fh, c, per_channel_spec, axes_lookup)

    # Then, apply one-per-file specs.
    apply_spec(fh, data, per_file_spec)

    # Finally, apply root attributes.
    for attr in root_attributes:
        value = root_attributes[attr]
        fh.attrs[attr] = to_bytes(value) if isinstance(value, str) else value

def apply_spec(fh, data, specs, lookup=None):
    for spec in specs:
        if spec['type'] == 'group':
            create_group(fh, data, spec, lookup)
        elif spec['type'] == 'dataset':
            create_dataset(fh, data, spec, lookup)
        else:
            raise ValueError('"type" must be "group" or "dataset"')

def create_group(fh, data, spec, lookup=None):
    """ Parses "group" type spec to create a group object. """

    if lookup:
        path_text = parse_path(spec['path'], lookup)
    else:
        path_text = spec['path']['text']

    fh.create_group(path_text)

    attributes = spec['attributes']
    if attributes:
        additional_atts = attributes.pop('ADD', None)
        if additional_atts:
            additional_atts_func = additional_atts.get('func')
            kwargs = additional_atts.get('kwargs')
            if kwargs is None:
                attributes.update(additional_atts_func(data))
            else:
                attributes.update(additional_atts_func(data, **kwargs))
        for attribute, params in attributes.items():

            if not isinstance(params, dict):
                value = params
                fh[path_text].attrs.create(
                        attribute, to_bytes(value)
                        )
                continue

            att_func = params.get('func')
            kwargs = params.get('kwargs')
            if kwargs is None:
                value = att_func(data)
            else:
                value = att_func(data, **kwargs)
            fh[path_text].attrs.create(
                    attribute, to_bytes(value)
                    )

def create_dataset(fh, data, spec, lookup=None):
    """ Parses "dataset" type spec to create a dataset object. """

    if lookup:
        path_text = parse_path(spec['path'], lookup)
    else:
        path_text = spec['path']['text']

    value = spec.get('value')
    if 'data' in value:
        data = value['data']

    value_func = value.get('func')
    if value_func:
        data = value_func(data)

    shape = data.shape if len(data.shape) > 0 else (1,)

    kwargs = {'name': path_text, 'shape': shape, 'data': data}

    kwds = value.get('kwargs')
    if kwds is not None:
        kwargs.update(kwds)

    fh.create_dataset(**kwargs)

################################################################################
#                             Helper Functions                                 #
################################################################################

def to_bytes(val):
    str_split_val = list(str(val))
    bytes_val = list(map(lambda x: bytes(x, 'utf-8'), str_split_val))

    return np.array(bytes_val, dtype=H5T_C_S1_64)

def parse_path(path, lookup):
    if 'values' in path:
        path_text = path['text'].format(
                *list(
                    map(lookup.get, path['values'])
                    )
                )
    else:
        path_text = path['text']

    return path_text
