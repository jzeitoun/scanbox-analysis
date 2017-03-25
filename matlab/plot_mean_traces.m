function plot_mean_traces(merged_roi,uip)

% initialize parameters
num_sfreqs = size(merged_roi.condition.attributes.sfrequencies,2);
num_frames = size(merged_roi.dtorientationsmeans{1, 1}.attributes.meantrace,2);  
on = merged_roi.dtorientationsmeans{1, 1}.attributes.on_frames;
bs = merged_roi.dtorientationsmeans{1, 1}.attributes.bs_frames;
x_axis = bs+1:(on+bs):num_frames;
xlabels = num2cell(merged_roi.condition.attributes.orientations);

% find max y vals
min_array = 1:num_sfreqs;
max_array = 1:num_sfreqs;
for k = 1:num_sfreqs
    min_array(k) = min(merged_roi.dtorientationsmeans{1,k}.attributes.matrix(:));
    max_array(k) = max(merged_roi.dtorientationsmeans{1,k}.attributes.matrix(:));
end
min_y = min(min_array)-1;
max_y = max(max_array)+1;

% get workspace names
fields = fieldnames(merged_roi.sorted_dtorientationsmeans);
colors = [[0.800,  1.000,  0.800]; [0.400,  0.600,  1.000]];
for i = 1:num_sfreqs
    mean_y = (merged_roi.dtorientationsmeans{1, i}.attributes.meantrace)';
    mean_x = (1:size(mean_y,1))';
    ax = subplot(num_sfreqs,1,i,'Parent',uip);
    cla(ax) % clear axes
    ylim([min_y max_y]);
    hold on
    for r = 1:size(x_axis,2)
        x_pos = x_axis(r)-bs;
        rectangle('Position',[x_pos min_y bs 100],'FaceColor',[0.15 0.15 0.15],'EdgeColor','None')
    end
    for k = 1:size(fields,1)
        field = fields{k};
        y = (merged_roi.sorted_dtorientationsmeans.(field){1,i}.matrix)';
        x = (repmat(1:size(y,1),size(y,2),1))';
        for n = 1:size(y,2)
            plot(ax,x,y(:,n),'Color',colors(k,:));
        end
    end
    ylabel(string(merged_roi.dtorientationsmeans{1, i}.attributes.trial_sf), 'FontSize', 15, 'Color', 'w');
    set(subplot(num_sfreqs,1,i),'Color',[0.4 0.4 0.4])
    plot(mean_x,mean_y,'r','LineWidth',2);
    xticks(x_axis);
    xticklabels(xlabels);
    ax.XColor = 'w';
    ax.YColor = 'w';
    set(gca, 'Ticklength', [0 0]);
    ax = gca;
    new_pos = ax.Position;
    new_pos(1) = 0.075;
    new_pos(3) = 0.9;
    set(ax,'Position',new_pos);
end