function batch_align(align_function)
% Aligns all files in directory using alignment function specified.

d = dir('*.sbx');

for(i=1:length(d))
    try
        filename = strtok(d(i).name,'.');
        if exist(['Aligned_' filename '.sbx']) == 0
            feval(align_function,filename);
        else
            fprintf('File %s is already aligned, skipping...\n',filename)
        end
    catch
        fprintf('Could not align %s.\n',filename)
    end
end
