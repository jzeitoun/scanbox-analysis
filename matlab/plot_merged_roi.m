function plot_merged_roi(merged_roi)

% initialize parameters
num_sfreqs = size(merged_rois.roi_1.condition.attributes.sfrequencies,2);
num_frames = size(merged_rois.roi_1.dtorientationsmeans{1, 1}.attributes.meantrace,2);  
on = merged_rois.roi_1.dtorientationsmeans{1, 1}.attributes.on_frames;
bs = merged_rois.roi_1.dtorientationsmeans{1, 1}.attributes.bs_frames;
x_axis = bs+1:(on+bs):num_frames;
xlabels = num2cell(merged_rois.roi_1.condition.attributes.orientations);

% find max y vals
min_array = 1:num_sfreqs;
max_array = 1:num_sfreqs;
for k = 1:num_sfreqs
    min_array(i) = min(merged_rois.roi_1.dtorientationsmeans{1,k}.attributes.matrix(:));
    max_array(i) = max(merged_rois.roi_1.dtorientationsmeans{1,k}.attributes.matrix(:));
end
min_y = min(min_array)-1;
max_y = max(max_array)+1;

figure('Name', 'Orientation Averages');
for i = 1:num_sfreqs
    mean_y = (merged_roi.dtorientationsmeans{1, i}.attributes.meantrace)';
    mean_x = (1:size(mean_y,1))';
    y = (merged_roi.dtorientationsmeans{1, i}.attributes.matrix)';
    x = (repmat(1:size(y,1),size(y,2),1))';
    subplot(num_sfreqs,1,i);
    hold on
    for r = 1:size(x_axis,2)
        x_pos = x_axis(r)-on;
        rectangle('Position',[x_pos min_y bs max_y+abs(min_y)],'FaceColor',[0.1 0.1 0.1],'EdgeColor','None')
    end
    for n = 1:size(y,2)
        plot(x,y(:,n),'Color',[1 1 1]);
    end
    set(subplot(num_sfreqs,1,i),'Color',[0.6 0.6 0.6])
    plot(mean_x,mean_y,'r');
    ylim([min_y max_y])
    xticks(x_axis);
    xticklabels(xlabels);
end