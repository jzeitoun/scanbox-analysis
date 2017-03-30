function plot_stats(merged_roi,table)

headers = {'Anova All|F'; 'Anova All|P';...
    'SF Cutoff Rel33|X'; 'SF Cutoff Rel33|Y'; 'SF|Peak'; 'SF|Pref'; 'SF|Bandwidth'; 'SF|Global OPref';...
    '@'; 'OSI'; 'CV'; 'DSI'; 'Sigma'; 'OPref'; 'RMax'; 'Residual';...
    'Anova Each|F'; 'Anova Each|P'};
set(table,'ColumnName', headers);
num_sfreqs = size(merged_roi.condition.attributes.sfrequencies,2);
data = num2cell(zeros(num_sfreqs,18));
data(:,:) = {''};

% Assign values to data array
data(1,3) = {merged_roi.dtsfreqfits{1, 1}.attributes.value.rc33(1)};
data(1,4) = {merged_roi.dtsfreqfits{1, 1}.attributes.value.rc33(2)};
data(1,5) = {merged_roi.dtsfreqfits{1, 1}.attributes.value.peak};
data(1,6) = {merged_roi.dtsfreqfits{1, 1}.attributes.value.pref};
data(1,7) = {merged_roi.dtsfreqfits{1, 1}.attributes.value.ratio};
data(1,8) = {merged_roi.dtorientationbestprefs{1, 1}.attributes.value};
data(:,9) = num2cell((merged_roi.condition.attributes.sfrequencies));

for i = 1:num_sfreqs
    data(i,10) = {merged_roi.dtorientationsfits{1, i}.attributes.value.osi};
    data(i,11) = {merged_roi.dtorientationsfits{1, i}.attributes.value.cv};
    data(i,12) = {merged_roi.dtorientationsfits{1, i}.attributes.value.dsi};
    data(i,13) = {merged_roi.dtorientationsfits{1, i}.attributes.value.sigma};
    data(i,14) = {merged_roi.dtorientationsfits{1, i}.attributes.value.o_pref};
    data(i,15) = {merged_roi.dtorientationsfits{1, i}.attributes.value.r_max};
    data(i,16) = {merged_roi.dtorientationsfits{1, i}.attributes.value.residual};
    data(i,17) = {merged_roi.dtanovaeachs{1, i}.attributes.f}; 
    data(i,18) = {merged_roi.dtanovaeachs{1, i}.attributes.p};
end

% Update table
set(table,'Data',data);
 


