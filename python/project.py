import numpy as np
import tifffile as tif
import sys
import os

from sbxmap import sbxmap

projection_methods = {
        'max': np.max,
        'mean': np.mean,
        'sum': np.sum,
        'std': np.std
        }

def convert_sum(projection):
    return 2*16-1 * (projection.astype('float32')/np.max(projection))

def generate_projection(method):
    '''
    Walks through all subdirectories of the current folder and forms a projection
    image of all aligned sbx files using the specified method.
    '''
    #tif_files = []
    for path, dirs, files in os.walk(os.getcwd()):
        sbx_files = [f for f in files if f.startswith('moco') and f.endswith('.sbx')]
        for sbx_file in sbx_files:
            full_sbx_path = os.path.join(path, sbx_file)
            sbx_basename = os.path.splitext(full_sbx_path)[0]
            tif_name = '{}_{}.tif'.format(sbx_basename, method)
            if os.path.exists(tif_name) or '098_008_005' in tif_name:
                print('{} exists, skipping'.format(tif_name))
            else:
                print('Processing: {}'.format(full_sbx_path))
                sbx = sbxmap(full_sbx_path)
                data = sbx.data()['green']['plane_0']
                projection = projection_methods[method](~data, 0)
                if method == 'sum':
                    projection = convert_sum(projection)
                tif.imsave('{}_{}.tif'.format(sbx_basename, method), projection.astype('uint16'))
                #tif_files.append('{}_{}.tif'.format(sbx_basename, method))

    #with open('dryrun.txt', 'w') as f:
    #    for line in tif_files:
    #        f.write(line + '\n')

def main():
    generate_projection(sys.argv[1])

if __name__ == '__main__':
    main()
