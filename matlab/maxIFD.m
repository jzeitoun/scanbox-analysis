function maxIFD = maxIFD(tiff)
    
while tiff.lastDirectory ~= 1
    tiff.nextDirectory;
end
maxIFD = tiff.currentDirectory;
end