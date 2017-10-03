function plot_t_curve(merged_roi,axes)

% Initialize parameters
sfy = merged_roi.dtsfreqfits{1, 1}.attributes.value.sfy;
sfx = merged_roi.dtsfreqfits{1, 1}.attributes.value.sfx;
y_fit = merged_roi.dtsfreqfits{1, 1}.attributes.value.dog_y;
x_fit = merged_roi.dtsfreqfits{1, 1}.attributes.value.dog_x;

% Plot tuning curve
p = plot(axes,sfx,sfy,x_fit,y_fit);
%xticks(sfx);
%xticklabels(xlabels);
p(1).LineWidth = 2;
p(1).Color = [0.0 0.8 1.0];
p(2).LineWidth = 2;
p(2).Color = [1.0 0.6 0.0];
set(axes,'Color',[0.4 0.4 0.4]);
axes.XColor = 'w';
axes.YColor = 'w';
axes.XLim = [sfx(1) sfx(end)];

