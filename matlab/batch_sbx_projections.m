function batch_sbx_projections()

d = dir('*.sbx');

parfor i = 1:length(d)
    if d(i).bytes < 50000000 % check if size is bigger than 50mb
        fn = strtok(d(i).name,'.');
        sbx_rgProjections(fn)
    end
end

end
    