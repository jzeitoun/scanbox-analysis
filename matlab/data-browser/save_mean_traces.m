function save_mean_traces(merged_roi,fname,current_roi)

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
    fig = figure();
    fig.Position = [360 278 560 80];
    mean_y = (merged_roi.dtorientationsmeans{1, i}.attributes.meantrace)';
    mean_x = (1:size(mean_y,1))';
    ax = gca;
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
            plot(x,y(:,n),'Color',colors(k,:));
        end
    end
    sf = merged_roi.dtorientationsmeans{1, i}.attributes.trial_sf;
    ylabel(string(sf), 'FontSize', 15, 'Color', 'k');
    plot(mean_x,mean_y,'r','LineWidth',2);
    set(gca, 'Color', [0.4 0.4 0.4]);
    set(gca, 'xtick', x_axis);
    set(gca, 'xticklabel', xlabels);
    set(gca, 'Ticklength', [0 0]);
    set(gcf,'InvertHardCopy','off');
    saveas(fig,[fname(1:end-4), '_', current_roi, '/', 'sf_', num2str(sf), '.svg']);
    close(gcf);
end