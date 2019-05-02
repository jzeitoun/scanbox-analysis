from sbxmap import *
import tifffile as tif
import os

def averageFrames(directory,file,channel,plane):
	animal_dir = directory
	os.chdir(animal_dir)

	d_sbx = sbxmap(file)

	plane = d_sbx.data()[channel][plane]

	frames = np.floor(plane.shape[0]/10)
	plane = plane[:(frames*10)]
	output = plane.reshape(frames,10,plane.shape[1],plane.shape[2]).mean(axis=1)
	tif.imsave('averaged_python.tif',output)
	with open('averaged_python.sbx', 'w') as f:
		np.save(f, output, allow_pickle=False)

