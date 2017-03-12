%% YuanYuan Zhang: reproject MOD29-swath product into Arctic PS
% author: TengLi 20170311, litengbnu@foxmail.com, this is main function;
%% read MOD29 HDF file and prepare data
clear
spatial_error = 2000;
work_space = 'C:\Users\lt\Downloads\20170311-zyy-Swath_Reprojection\';
file_name = 'MOD29.A2017036.0030.006.2017036133007.hdf';
temp = hdfread([work_space, file_name], 'MOD_Swath_Sea_Ice', 'Fields','Ice_Surface_Temperature');
orig_lat = hdfread([work_space, file_name], 'MOD_Swath_Sea_Ice', 'Fields','Latitude');
orig_lon = hdfread([work_space, file_name], 'MOD_Swath_Sea_Ice', 'Fields','Longitude');
% oversample by five fold and interpolate the nan value
% lat = dyadup(orig_lat, 'm'); % double every time!
% from http://cn.mathworks.com/matlabcentral/fileexchange/4551-inpaint-nans
[temp_row, temp_col] = size(temp);
% construct row and column geo lookup table
% Liuqiang's schema is convert geo_table projection
% but useless for me since I cannot convert in advance.
row_table = repmat(int16((1:temp_row)'),1,temp_col);
col_table = repmat(int16(1:temp_col),temp_row,1);

lat = five_sample(orig_lat); lat = lat(1:temp_row,1:temp_col);
lon = five_sample(orig_lon); lon = lon(1:temp_row,1:temp_col);

%% convert lat/lon to Arctic PS projection
% https://cn.mathworks.com/matlabcentral/fileexchange/32950-polar-stereographic-coordinate-transformation--lat-lon-to-map-
[ps_x,ps_y] = polarstereo_fwd(lat,lon,[],[],71,0);
max_x = max(max(ps_x)); min_x = min(min(ps_x)); 
max_y = max(max(ps_y)); min_y = min(min(ps_y));
% construct vacant matrix to feed hdf data (forward)
feed_data = zeros(round((max_x - min_x)/1000), round((max_y - min_y)/1000));
[feed_samples, feed_lines] = size(feed_data);
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% forward method: there are too many void between non-value pixels
% for geo_ii = 1:temp_row
%     for geo_jj = 1:temp_col
%         ps_row = round((ps_x(geo_ii,geo_jj) - min_x)/1000)+1;
%         ps_col = round((ps_y(geo_ii,geo_jj) - min_y)/1000)+1;
%         feed_data(ps_row, ps_col) = temp(geo_ii,geo_jj);
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% backward method, traverse 2-dimension image (much slower!)
%{
for ps_ii = 1:feed_samples
    if ps_ii ==1
        ps_x_back = min_x;
    else
%         ps_x_back = min_x + 1000*(ps_ii - 1);
        ps_x_back = ps_x_back + 1000;
    end
    for ps_jj = 1:feed_lines
        if ps_jj == 1
            ps_y_back = min_y;
        else
%             ps_y_back = min_y + 1000*(ps_jj - 1);
            ps_y_back = ps_y_back + 1000;
        end

%         diff_x_back = abs(ps_x - ps_x_back);
%         diff_y_back = abs(ps_y - ps_y_back);
%         diff_x_back = bsxfun(@minus, ps_x, ps_x_back);
%         diff_y_back = bsxfun(@minus, ps_y, ps_y_back);
%         加入先验知识在附近找？否则全遍历太慢了！
        diff_sum_back = abs(bsxfun(@minus, ps_x, ps_x_back)) + abs(bsxfun(@minus, ps_y, ps_y_back));
        [min_diff, min_index] = min(diff_sum_back(:));
        if min_diff < spatial_error
            [diff_row, diff_col] = ind2sub(size(diff_sum_back), min_index);
            feed_data(ps_ii, ps_jj) = temp(diff_row, diff_col);
        else
%             feed_data(ps_ii, ps_jj) = nan;
        end
    end
end
%}
%% backward method, calculate row/col index directly (faster!)

for ps_ii = 1:feed_samples
    ps_x_back = min_x + 1000*(ps_ii - 1);
    for ps_jj = 1:feed_lines
        ps_y_back = min_y + 1000*(ps_jj - 1);


        diff_sum_back = abs(bsxfun(@minus, ps_x, ps_x_back)) + abs(bsxfun(@minus, ps_y, ps_y_back));
        [min_diff, min_index] = min(diff_sum_back(:));
        if min_diff < spatial_error
            [diff_row, diff_col] = ind2sub(size(diff_sum_back), min_index);
            feed_data(ps_ii, ps_jj) = temp(diff_row, diff_col);
        else
%             feed_data(ps_ii, ps_jj) = nan;
        end
    end
end
%% write binary (after permulate) and hdr file (text model)
binary_name=fullfile(work_space,[file_name(1:end-4),'_PS.dat']);
fid=fopen(binary_name,'wb');
fwrite(fid,fliplr(int16(feed_data)),'int16');
% mainpulate the primitive matrix to align reults from 
% fwrite(fid,int16(feed_data),'int16');
% fwrite(fid,flipud(int16(feed_data)),'int16');
% fwrite(fid,transpose(int16(feed_data)),'int16');
% fwrite(fid,rot90(int16(feed_data)),'int16');
fclose(fid);
hdr_name = fullfile(work_space, [file_name(1:end-4), '_PS.hdr']);
write_hdr(hdr_name, feed_samples, feed_lines, min_x, max_y);

%% end up with default laughter
load laughter laughter
sound(laughter)
